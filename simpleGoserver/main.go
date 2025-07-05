package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/alexedwards/scs/v2"
	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/net/context"
	"golang.org/x/oauth2"
)

type Post struct {
	ID   int    `json:"id"`
	Body string `json:"body"`
}

type User struct {
	Id    int    `json:"id"`
	Login string `json:"login"`
}

var (
	clientID     = os.Getenv("GITHUB_OAUTH2_CLIENT_ID")
	clientSecret = os.Getenv("GITHUB_OAUTH2_CLIENT_SECRET")
	domain       = os.Getenv("DOMAIN")
	authconfig   oauth2.Config
	// verifier     *oidc.IDTokenVerifier
	ctx            context.Context
	provider       *oidc.Provider
	sessionManager *scs.SessionManager
	mux            *http.ServeMux
)

// containsDotFile reports whether name contains a path element starting with a period.
// The name is assumed to be a delimited by forward slashes, as guaranteed
// by the http.FileSystem interface.
func containsDotFile(name string) bool {
	parts := strings.Split(name, "/")
	for _, part := range parts {
		if strings.HasPrefix(part, ".") {
			return true
		}
	}
	return false
}

// dotFileHidingFile is the http.File use in dotFileHidingFileSystem.
// It is used to wrap the Readdir method of http.File so that we can
// remove files and directories that start with a period from its output.
type dotFileHidingFile struct {
	http.File
}

// Readdir is a wrapper around the Readdir method of the embedded File
// that filters out all files that start with a period in their name.
func (f dotFileHidingFile) Readdir(n int) (fis []fs.FileInfo, err error) {
	files, err := f.File.Readdir(n)
	for _, file := range files { // Filters out the dot files
		if !strings.HasPrefix(file.Name(), ".") {
			fis = append(fis, file)
		}
	}
	if err == nil && n > 0 && len(fis) == 0 {
		err = io.EOF
	}
	return
}

// dotFileHidingFileSystem is an http.FileSystem that hides
// hidden "dot files" from being served.
type dotFileHidingFileSystem struct {
	http.FileSystem
}

// Open is a wrapper around the Open method of the embedded FileSystem
// that serves a 403 permission error when name has a file or directory
// with whose name starts with a period in its path.
func (fsys dotFileHidingFileSystem) Open(name string) (http.File, error) {
	if containsDotFile(name) { // If dot file, return 403 response
		return nil, fs.ErrPermission
	}

	file, err := fsys.FileSystem.Open(name)
	if err != nil {
		return nil, err
	}
	return dotFileHidingFile{file}, err
}

func randString(nByte int) (string, error) {
	b := make([]byte, nByte)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func getUserDetails(token string) (User, error) {

	var user User

	req, err := http.NewRequest("GET", "https://api.github.com/user", nil)

	if err != nil {
		log.Fatalf("Error creating request: %v", err)
	}

	req.Header.Add("Authorization", "Bearer "+token)

	client := &http.Client{}

	resp, err := client.Do(req)

	if err != nil {
		log.Fatalf("Error performing request: %v", err)
	}
	defer resp.Body.Close()

	log.Println("response")
	log.Println(resp.StatusCode)

	/* 	body, err := io.ReadAll(resp.Body)
	   	if err != nil {
	   		log.Fatalf("Error reading response body: %v", err)
	   	} */
	//json.Unmarshal(body, &user)

	json.NewDecoder(resp.Body).Decode(&user)

	return user, nil

}

/* func setCallbackCookie(w http.ResponseWriter, r *http.Request, name, value string) {
	c := &http.Cookie{
		Name:     name,
		Value:    value,
		MaxAge:   int(time.Hour.Seconds()),
		Secure:   r.TLS != nil,
		HttpOnly: true,
	}
	http.SetCookie(w, c)
} */

func main() {

	dbconnect()

	fsys := dotFileHidingFileSystem{http.Dir("ui/build")}

	sessionManager = scs.New()
	sessionManager.Lifetime = 5 * time.Minute
	sessionManager.Cookie.Domain = domain
	sessionManager.Cookie.HttpOnly = true
	sessionManager.Cookie.Secure = true
	sessionManager.Cookie.Persist = true

	mux = http.NewServeMux()

	ctx = context.Background()
	/* resp, err := http.Get("https://github.com/login/oauth/.well-known/openid-configuration")
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close() */

	// Parse config from JSON metadata.
	providerConfig := &oidc.ProviderConfig{}
	/* if err := json.NewDecoder(resp.Body).Decode(providerConfig); err != nil {
		log.Fatal(err)
	} */

	providerConfig.UserInfoURL = "https://api.github.com/user"
	providerConfig.AuthURL = "https://github.com/login/oauth/authorize"
	providerConfig.TokenURL = "https://github.com/login/oauth/access_token"

	provider = providerConfig.NewProvider(ctx)
	/*     if err != nil {
		log.Fatal(err)
	} */

	/* 	oidcConfig := &oidc.Config{
	   		ClientID: clientID,
	   	}

	   	verifier = provider.Verifier(oidcConfig) */

	redirectUrl := fmt.Sprintf("https://posts.%s/auth/github/callback", domain)
	scopes := []string{oidc.ScopeOpenID, "read:user", "user:email"}

	authconfig = oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint: oauth2.Endpoint{
			AuthURL:  "https://github.com/login/oauth/authorize",
			TokenURL: "https://github.com/login/oauth/access_token",
		},
		RedirectURL: redirectUrl,
		Scopes:      scopes,
	}

	// provider, err := oidc.NewProvider(ctx, "https://accounts.google.com")

	mux.HandleFunc("/posts", postsHandler)
	mux.HandleFunc("/posts/", postHandler)
	//mux.HandleFunc("/", fallbackHandler)
	mux.HandleFunc("/userinfo", userInfoHandler)
	mux.HandleFunc("/auth/github/callback", oauthHandler)
	mux.HandleFunc("/auth/login", loginHandler)
	mux.HandleFunc("/logout", logoutHandler)
	mux.HandleFunc("/healthcheck", healthcheckHandler)

	//http.Handle("/", http.FileServer(fsys))

	//http.Handle("/tmpfiles/", http.StripPrefix("/tmpfiles/", http.FileServer(http.Dir("/tmp"))))
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

func loginHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {
		http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
	} else {
		state, err := randString(16)
		if err != nil {
			http.Error(w, "Internal error", http.StatusInternalServerError)
			return
		}
		nonce, err := randString(16)
		if err != nil {
			http.Error(w, "Internal error", http.StatusInternalServerError)
			return
		}

		sessionManager.Put(r.Context(), "state", state)
		sessionManager.Put(r.Context(), "nonce", nonce)

		/* 	setCallbackCookie(w, r, "state", state)
		setCallbackCookie(w, r, "nonce", nonce) */
		http.Redirect(w, r, authconfig.AuthCodeURL(state), http.StatusFound)
	}
}

func oauthHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {
		http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
	} else {
		state := sessionManager.GetString(r.Context(), "state")

		if r.URL.Query().Get("state") != state {
			http.Error(w, "state did not match", http.StatusBadRequest)
			return
		}

		oauth2Token, err := authconfig.Exchange(ctx, r.URL.Query().Get("code"))

		if err != nil {
			http.Error(w, "Failed to exchange token: "+err.Error(), http.StatusInternalServerError)
			return
		}

		log.Println("Reading OauthToken")

		res2B, _ := json.Marshal(oauth2Token)
		log.Println(string(res2B))

		/*     rawIDToken, ok := oauth2Token.Extra("id_token").(string)
		if !ok {
			http.Error(w, "No id_token field in oauth2 token.", http.StatusInternalServerError)
			return
		}

		idToken, err := verifier.Verify(ctx, rawIDToken)
		if err != nil {
			http.Error(w, "Failed to verify ID Token: "+err.Error(), http.StatusInternalServerError)
			return
		} */

		// rawAccessToken := oauth2Token.AccessToken
		/* 	if err != nil {
			http.Error(w, "No Access oauth2 token.", http.StatusInternalServerError)
			return
		} */

		/* 	accessToken, err := verifier.Verify(ctx, rawAccessToken)
		if err != nil {
			http.Error(w, "Failed to verify Access Token: "+err.Error(), http.StatusInternalServerError)
			return
		} */

		/* 	nonce, err := r.Cookie("nonce")
		if err != nil {
			http.Error(w, "nonce not found", http.StatusBadRequest)
			return
		}
		if accessToken.Nonce != nonce.Value {
			http.Error(w, "nonce did not match", http.StatusBadRequest)
			return
		} */

		/* 		userInfo, err := provider.UserInfo(ctx, oauth2.StaticTokenSource(oauth2Token))
		   		if err != nil {
		   			http.Error(w, "Failed to get userinfo: "+err.Error(), http.StatusInternalServerError)
		   			return
		   		}

		   		resp := struct {
		   			OAuth2Token *oauth2.Token
		   			UserInfo    *oidc.UserInfo
		   		}{oauth2Token, userInfo}
		   		data, err := json.MarshalIndent(resp, "", "    ")
		   		if err != nil {
		   			http.Error(w, err.Error(), http.StatusInternalServerError)
		   			return
		   		}

		   		log.Println("Reading UserInfo") */
		/*
			res2C, _ := json.Marshal(data)
			log.Println(string(res2C)) */
		sessionManager.Put(r.Context(), "oauthtoken", oauth2Token.AccessToken)
		//sessionManager.Put(r.Context(), "userinfo", data)
		userDetails, err := getUserDetails(oauth2Token.AccessToken)
		if err != nil {
			log.Fatal("Failed to fetch user details", err)
		}

		res2C, _ := json.Marshal(userDetails)
		log.Println(string(res2C))

		//userDetailsHeader := fmt.Sprintf("%s %d", userDetails.login, userDetails.id)

		sessionManager.Put(r.Context(), "login", userDetails.Login)
		sessionManager.Put(r.Context(), "id", userDetails.Id)

		token, expiry, err := sessionManager.Commit(r.Context())

		if err != nil {
			log.Fatal("Failed to store session", err)
		}

		sessionManager.WriteSessionCookie(r.Context(), w, token, expiry)

		http.Redirect(w, r, "/", http.StatusTemporaryRedirect)

		/*     resp := struct {
			OAuth2Token   *oauth2.Token
			AccessTokenClaims *json.RawMessage // ID Token payload is just JSON.
		}{oauth2Token, new(json.RawMessage)}

		if err := idToken.Claims(&resp.IDTokenClaims); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		data, err := json.MarshalIndent(resp, "", "    ")
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		} */
	}

}

func userInfoHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {

		switch r.Method {
		case "GET":
			var user User
			user.Login = sessionManager.GetString(r.Context(), "login")
			user.Id = sessionManager.GetInt(r.Context(), "id")

			jsonres, err := json.Marshal(user)
			if err != nil {
				log.Fatal("Failed to retrieve user", err)
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
		log.Fatalf("Not able to get posts from db", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	ps := make([]Post, 0, len(dbposts))
	for i := 0; i < len(dbposts); i++ {
		ps[i].ID = int(dbposts[i].ID)
		ps[i].Body = dbposts[i].Body
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
		log.Fatalf("Not able to insert posts to db", err)
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
		log.Fatalf("Not able to get post from db", err)
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
		log.Fatalf("Not able to get post from db", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	if userId != dbpost.Userid {
		http.Error(w, "You dont have access to this Post", http.StatusForbidden)
	}
	res, err := deldbPost(id)
	if err != nil {
		log.Fatalf("Not able to delete post from db", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	if !res {
		log.Fatalf("Not able to delete post from db", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}

	w.WriteHeader(http.StatusOK)
}
