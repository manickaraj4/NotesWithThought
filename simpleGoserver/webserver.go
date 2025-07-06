package main

import (
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/alexedwards/scs/v2"
)

var (
	mux            *http.ServeMux
	sessionManager *scs.SessionManager
)

func containsDotFile(name string) bool {
	parts := strings.Split(name, "/")
	for _, part := range parts {
		if strings.HasPrefix(part, ".") {
			return true
		}
	}
	return false
}

type dotFileHidingFile struct {
	http.File
}

func (f dotFileHidingFile) Readdir(n int) (fis []fs.FileInfo, err error) {
	files, err := f.File.Readdir(n)
	for _, file := range files {
		if !strings.HasPrefix(file.Name(), ".") {
			fis = append(fis, file)
		}
	}
	if err == nil && n > 0 && len(fis) == 0 {
		err = io.EOF
	}
	return
}

type dotFileHidingFileSystem struct {
	http.FileSystem
}

func (fsys dotFileHidingFileSystem) Open(name string) (http.File, error) {
	if containsDotFile(name) {
		return nil, fs.ErrPermission
	}

	file, err := fsys.FileSystem.Open(name)
	if err != nil {
		return nil, err
	}
	return dotFileHidingFile{file}, err
}

func webServerInit() {
	fsys := dotFileHidingFileSystem{http.Dir("ui/build")}

	sessionManager = scs.New()
	sessionManager.Lifetime = 5 * time.Minute
	sessionManager.Cookie.Domain = domain
	sessionManager.Cookie.HttpOnly = true
	sessionManager.Cookie.Secure = true
	sessionManager.Cookie.Persist = true

	mux = http.NewServeMux()

	mux.HandleFunc("/posts", postsHandler)
	mux.HandleFunc("/posts/", postHandler)
	mux.HandleFunc("/github/userinfo", userInfoHandler)
	mux.HandleFunc("/auth/github/callback", githubOauthHandler)
	mux.HandleFunc("/auth/google/callback", googleOauthHandler)
	mux.HandleFunc("/auth/login/github", githubLoginHandler)
	mux.HandleFunc("/auth/login/google", googleLoginHandler)
	mux.HandleFunc("/logout", logoutHandler)
	mux.HandleFunc("/healthcheck", healthcheckHandler)

	mux.Handle("/", http.FileServer(fsys))

	fmt.Println("Server is running at http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", sessionManager.LoadAndSave(mux)))
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {

	sessionManager.Destroy(r.Context())
	http.Redirect(w, r, "/", http.StatusTemporaryRedirect)

}

func healthcheckHandler(w http.ResponseWriter, r *http.Request) {

	res := make(map[string]string)
	res["status"] = "ok"
	json.NewEncoder(w).Encode(res)

}

func postsHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {
		switch r.Method {
		case "GET":
			handleGetPosts(w, r)
		case "POST":
			handlePostPosts(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	} else {
		http.Error(w, "UnAuthorized", http.StatusUnauthorized)
	}
}

func postHandler(w http.ResponseWriter, r *http.Request) {
	if sessionManager.GetInt(r.Context(), "id") != 0 {
		id, err := strconv.Atoi(r.URL.Path[len("/posts/"):])
		if err != nil {
			http.Error(w, "Invalid post ID", http.StatusBadRequest)
			return
		}
		switch r.Method {
		case "GET":
			handleGetPost(w, r, id)
		case "DELETE":
			handleDeletePost(w, r, id)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	} else {
		http.Error(w, "UnAuthorized", http.StatusUnauthorized)
	}
}

func handleGetPosts(w http.ResponseWriter, r *http.Request) {
	userId := "github:" + strconv.Itoa(sessionManager.GetInt(r.Context(), "id")) + ":" + sessionManager.GetString(r.Context(), "login")
	dbposts, err := getdbPostsByUserId(userId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	var tempPost Post
	ps := make([]Post, 0, len(dbposts))
	for i := 0; i < len(dbposts); i++ {
		tempPost.ID = int(dbposts[i].ID)
		tempPost.Body = dbposts[i].Body
		ps = append(ps, tempPost)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ps)
}

func handlePostPosts(w http.ResponseWriter, r *http.Request) {
	var p Post
	var dbp DbPost

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusInternalServerError)
		return
	}

	if err := json.Unmarshal(body, &p); err != nil {
		http.Error(w, "Error parsing request body", http.StatusBadRequest)
		return
	}

	dbp.Body = p.Body
	dbp.Userid = "github:" + strconv.Itoa(sessionManager.GetInt(r.Context(), "id")) + ":" + sessionManager.GetString(r.Context(), "login")
	_, dberr := adddbPost(dbp)

	if dberr != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(p)
}

func handleGetPost(w http.ResponseWriter, r *http.Request, id int) {
	var p Post
	userId := "github:" + strconv.Itoa(sessionManager.GetInt(r.Context(), "id")) + ":" + sessionManager.GetString(r.Context(), "login")
	dbpost, err := getdbPostsBypostId(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}

	if userId != dbpost.Userid {
		http.Error(w, "You dont have access to this Post", http.StatusForbidden)
	}
	p.ID = int(dbpost.ID)
	p.Body = dbpost.Body

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(p)
}

func handleDeletePost(w http.ResponseWriter, r *http.Request, id int) {

	userId := "github:" + strconv.Itoa(sessionManager.GetInt(r.Context(), "id")) + ":" + sessionManager.GetString(r.Context(), "login")
	dbpost, err := getdbPostsBypostId(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	if userId != dbpost.Userid {
		http.Error(w, "You dont have access to this Post", http.StatusForbidden)
	}
	res, err := deldbPost(id)
	if err != nil {

		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	if !res {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}

	w.WriteHeader(http.StatusOK)
}

func userInfoHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {

		switch r.Method {
		case "GET":
			var user User
			user.Login = sessionManager.GetString(r.Context(), "login")
			user.Id = sessionManager.GetInt64(r.Context(), "id")

			jsonres, err := json.Marshal(user)
			if err != nil {
				http.Error(w, err.Error(), http.StatusUnauthorized)
			}
			w.Header().Set("Content-Type", "application/json")
			w.Write(jsonres)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}

	} else {
		http.Error(w, "UnAuthorized", http.StatusUnauthorized)
	}
}
