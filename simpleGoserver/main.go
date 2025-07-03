package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
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
	id    int    `json:"id"`
	login string `json:"login"`
}

var (
	posts        = make(map[int]Post)
	nextID       = 1
	postsMu      sync.Mutex
	clientID     = os.Getenv("GITHUB_OAUTH2_CLIENT_ID")
	clientSecret = os.Getenv("GITHUB_OAUTH2_CLIENT_SECRET")
	domain       = os.Getenv("DOMAIN")
	config       oauth2.Config
	// verifier     *oidc.IDTokenVerifier
	ctx            context.Context
	provider       *oidc.Provider
	sessionManager *scs.SessionManager
	mux            *http.ServeMux
)

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

	/* 	body, err := io.ReadAll(resp.Body)
	   	if err != nil {
	   		log.Fatalf("Error reading response body: %v", err)
	   	} */

	json.NewDecoder(resp.Body).Decode(&user)
	//json.Unmarshal(body, &user)

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

	config = oauth2.Config{
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
	mux.HandleFunc("/", fallbackHandler)
	mux.HandleFunc("/auth/github/callback", oauthHandler)
	mux.HandleFunc("/auth/login", loginHandler)
	mux.HandleFunc("/logout", logoutHandler)
	mux.HandleFunc("/healthcheck", healthcheckHandler)

	fmt.Println("Server is running at http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", sessionManager.LoadAndSave(mux)))
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {

	sessionManager.Destroy(r.Context())
	http.Redirect(w, r, "/auth/login", http.StatusTemporaryRedirect)

}

func healthcheckHandler(w http.ResponseWriter, r *http.Request) {

	res := make(map[string]string)
	res["status"] = "ok"
	json.NewEncoder(w).Encode(res)

}

func loginHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {
		http.Redirect(w, r, "/posts", http.StatusTemporaryRedirect)
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
		http.Redirect(w, r, config.AuthCodeURL(state), http.StatusFound)
	}
}

func fallbackHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {
		http.Redirect(w, r, "/posts", http.StatusTemporaryRedirect)
	} else {
		http.Redirect(w, r, "/auth/login", http.StatusMovedPermanently)
	}

	/*
	   	switch r.Method {

	   case "GET":

	   	http.Redirect(w, r, "/posts", http.StatusMovedPermanently)

	   default:

	   	    http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	   	}
	*/
}

func oauthHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetInt(r.Context(), "id") != 0 {
		http.Redirect(w, r, "/posts", http.StatusTemporaryRedirect)
	} else {
		state := sessionManager.GetString(r.Context(), "state")

		if r.URL.Query().Get("state") != state {
			http.Error(w, "state did not match", http.StatusBadRequest)
			return
		}

		oauth2Token, err := config.Exchange(ctx, r.URL.Query().Get("code"))

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

		//userDetailsHeader := fmt.Sprintf("%s %d", userDetails.login, userDetails.id)

		sessionManager.Put(r.Context(), "login", userDetails.login)
		sessionManager.Put(r.Context(), "id", userDetails.id)

		token, expiry, err := sessionManager.Commit(r.Context())

		if err != nil {
			log.Fatal("Failed to store session", err)
		}

		sessionManager.WriteSessionCookie(r.Context(), w, token, expiry)

		http.Redirect(w, r, "/posts", http.StatusTemporaryRedirect)

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
		http.Error(w, "Method not allowed", http.StatusUnauthorized)
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
		http.Error(w, "Method not allowed", http.StatusUnauthorized)
	}
}

func handleGetPosts(w http.ResponseWriter, r *http.Request) {
	// This is the first time we're using the mutex.
	// It essentially locks the server so that we can
	// manipulate the posts map without worrying about
	// another request trying to do the same thing at
	// the same time.
	postsMu.Lock()

	// I love this feature of go - we can defer the
	// unlocking until the function has finished executing,
	// but define it up the top with our lock. Nice and neat.
	// Caution: deferred statements are first-in-last-out,
	// which is not all that intuitive to begin with.
	defer postsMu.Unlock()

	// Copying the posts to a new slice of type []Post
	ps := make([]Post, 0, len(posts))
	for _, p := range posts {
		ps = append(ps, p)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ps)
}

func handlePostPosts(w http.ResponseWriter, r *http.Request) {
	var p Post

	// This will read the entire body into a byte slice
	// i.e. ([]byte)
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusInternalServerError)
		return
	}

	// Now we'll try to parse the body. This is similar
	// to JSON.parse in JavaScript.
	if err := json.Unmarshal(body, &p); err != nil {
		http.Error(w, "Error parsing request body", http.StatusBadRequest)
		return
	}

	// As we're going to mutate the posts map, we need to
	// lock the server again
	postsMu.Lock()
	defer postsMu.Unlock()

	p.ID = nextID
	nextID++
	posts[p.ID] = p

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(p)
}

func handleGetPost(w http.ResponseWriter, r *http.Request, id int) {
	postsMu.Lock()
	defer postsMu.Unlock()

	p, ok := posts[id]
	if !ok {
		http.Error(w, "Post not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(p)
}

func handleDeletePost(w http.ResponseWriter, r *http.Request, id int) {
	postsMu.Lock()
	defer postsMu.Unlock()

	// If you use a two-value assignment for accessing a
	// value on a map, you get the value first then an
	// "exists" variable.
	_, ok := posts[id]
	if !ok {
		http.Error(w, "Post not found", http.StatusNotFound)
		return
	}

	delete(posts, id)
	w.WriteHeader(http.StatusOK)
}
