package main

import (
    "crypto/rand"
    "encoding/base64"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "strconv"
    "os"
    "time"
    "sync"

    "github.com/coreos/go-oidc/v3/oidc"
    "golang.org/x/net/context"
    "golang.org/x/oauth2"
)

type Post struct {
    ID   int    `json:"id"`
    Body string `json:"body"`
}

var (
    posts   = make(map[int]Post)
    nextID  = 1
    postsMu sync.Mutex
	clientID     = os.Getenv("GITHUB_OAUTH2_CLIENT_ID")
	clientSecret = os.Getenv("GITHUB_OAUTH2_CLIENT_SECRET")
    domain  = os.Getenv("DOMAIN")
    config oauth2.Config
    verifier *oidc.IDTokenVerifier
)

func randString(nByte int) (string, error) {
	b := make([]byte, nByte)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func setCallbackCookie(w http.ResponseWriter, r *http.Request, name, value string) {
	c := &http.Cookie{
		Name:     name,
		Value:    value,
		MaxAge:   int(time.Hour.Seconds()),
		Secure:   r.TLS != nil,
		HttpOnly: true,
	}
	http.SetCookie(w, c)
}

func main() {
    // ctx := context.Background()
    resp, err := http.Get("https://github.com/login/oauth/.well-known/openid-configuration")
    if err != nil {
        log.Fatal(err)
    }
    defer resp.Body.Close()
    
    // Parse config from JSON metadata.
    providerConfig := &oidc.ProviderConfig{}
    if err := json.NewDecoder(resp.Body).Decode(providerConfig); err != nil {
        log.Fatal(err)
    }

    log.Println("Reading Body")

    res2B, _ := json.Marshal(providerConfig)
    log.Println(string(res2B))

    provider := providerConfig.NewProvider(context.Background())
/*     if err != nil {
		log.Fatal(err)
	} */

    oidcConfig := &oidc.Config{
		ClientID: clientID,
	}

    verifier = provider.Verifier(oidcConfig)

    redirectUrl := fmt.Sprintf("https://posts.%s/auth/github/callback", domain)
    scopes := []string{oidc.ScopeOpenID}

    config = oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:    oauth2.Endpoint{
			AuthURL:  "https://github.com/login/oauth/authorize",
			TokenURL: "https://github.com/login/oauth/token",
		},
		RedirectURL:  redirectUrl,
		Scopes:   scopes,
	}

    // provider, err := oidc.NewProvider(ctx, "https://accounts.google.com")

    http.HandleFunc("/posts", postsHandler)
    http.HandleFunc("/posts/", postHandler)
    http.HandleFunc("/", fallbackHandler)
    http.HandleFunc("/auth/google/callback", oauthHandler)

    fmt.Println("Server is running at http://localhost:8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}

func fallbackHandler(w http.ResponseWriter, r *http.Request) {
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

    setCallbackCookie(w, r, "state", state)
    setCallbackCookie(w, r, "nonce", nonce)
    http.Redirect(w, r, config.AuthCodeURL(state, oidc.Nonce(nonce)), http.StatusFound)

/*     switch r.Method {
    case "GET":
        http.Redirect(w, r, "/posts", http.StatusMovedPermanently)
    default:
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
    } */
}

func oauthHandler(w http.ResponseWriter, r *http.Request) {
    state, err := r.Cookie("state")
    if err != nil {
        http.Error(w, "state not found", http.StatusBadRequest)
        return
    }
    if r.URL.Query().Get("state") != state.Value {
        http.Error(w, "state did not match", http.StatusBadRequest)
        return
    }

    oauth2Token, err := config.Exchange(context.Background(), r.URL.Query().Get("code"))

    if err != nil {
        http.Error(w, "Failed to exchange token: "+err.Error(), http.StatusInternalServerError)
        return
    }

    rawIDToken, ok := oauth2Token.Extra("id_token").(string)
    if !ok {
        http.Error(w, "No id_token field in oauth2 token.", http.StatusInternalServerError)
        return
    }

    idToken, err := verifier.Verify(context.Background(), rawIDToken)
    if err != nil {
        http.Error(w, "Failed to verify ID Token: "+err.Error(), http.StatusInternalServerError)
        return
    }

    nonce, err := r.Cookie("nonce")
    if err != nil {
        http.Error(w, "nonce not found", http.StatusBadRequest)
        return
    }
    if idToken.Nonce != nonce.Value {
        http.Error(w, "nonce did not match", http.StatusBadRequest)
        return
    }

    oauth2Token.AccessToken = "Access_Granted"

    resp := struct {
        OAuth2Token   *oauth2.Token
        IDTokenClaims *json.RawMessage // ID Token payload is just JSON.
    }{oauth2Token, new(json.RawMessage)}

    if err := idToken.Claims(&resp.IDTokenClaims); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    data, err := json.MarshalIndent(resp, "", "    ")
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    w.Write(data)

}

func postsHandler(w http.ResponseWriter, r *http.Request) {
    switch r.Method {
    case "GET":
        handleGetPosts(w, r)
    case "POST":
        handlePostPosts(w, r)
    default:
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
    }
}

func postHandler(w http.ResponseWriter, r *http.Request) {
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