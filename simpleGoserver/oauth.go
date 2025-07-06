package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"
)

var (
	githubClientId     string
	githubClientSecret string
	googleClientId     string
	googleClientSecret string
	githubAuthConfig   oauth2.Config
	googleAuthConfig   oauth2.Config
	googleProvider     *oidc.Provider
	githubProvider     *oidc.Provider
	verifier           *oidc.IDTokenVerifier
)

func randString(nByte int) (string, error) {
	b := make([]byte, nByte)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func googleInit() {

	var providerErr error
	googleProvider, providerErr = oidc.NewProvider(ctx, "https://accounts.google.com")

	if providerErr != nil {
		log.Fatal(providerErr)
	}

	var paramFetchErr error
	googleClientId, paramFetchErr = ssmFetchParam("GoogleOAuthID", true)
	if paramFetchErr != nil {
		log.Fatalf("Internal error: Google Client not be fetched from ssm", paramFetchErr)
	}

	googleClientSecret, paramFetchErr = ssmFetchParam("GoogleOAuthSecret", true)
	if paramFetchErr != nil {
		log.Fatalf("Internal error: Google Secret not be fetched from ssm", paramFetchErr)
	}

	oidcConfig := &oidc.Config{
		ClientID: googleClientId,
	}
	verifier = googleProvider.Verifier(oidcConfig)

	scopes := []string{oidc.ScopeOpenID, "https://www.googleapis.com/auth/userinfo.profile", "https://www.googleapis.com/auth/userinfo.email"}
	redirectUrl := fmt.Sprintf("https://posts.%s/auth/google/callback", domain)

	googleAuthConfig = oauth2.Config{
		ClientID:     googleClientId,
		ClientSecret: googleClientSecret,
		RedirectURL:  redirectUrl,
		Scopes:       scopes,
		Endpoint:     googleProvider.Endpoint(),
	}

}

func githubInit() {

	githubProviderConfig := &oidc.ProviderConfig{}

	githubProviderConfig.UserInfoURL = "https://api.github.com/user"
	githubProviderConfig.AuthURL = "https://github.com/login/oauth/authorize"
	githubProviderConfig.TokenURL = "https://github.com/login/oauth/access_token"

	githubProvider = githubProviderConfig.NewProvider(ctx)

	redirectUrl := fmt.Sprintf("https://posts.%s/auth/github/callback", domain)

	var paramFetchErr error
	githubClientId, paramFetchErr = ssmFetchParam("GithubOAuthID", true)
	if paramFetchErr != nil {
		log.Fatalf("Internal error: Github Client not be fetched from ssm", paramFetchErr)
	}

	githubClientSecret, paramFetchErr = ssmFetchParam("GithubOAuthSecret", true)
	if paramFetchErr != nil {
		log.Fatalf("Internal error: Github Secret not be fetched from ssm", paramFetchErr)
	}

	scopes := []string{oidc.ScopeOpenID, "read:user", "user:email"}
	githubAuthConfig = oauth2.Config{
		ClientID:     githubClientId,
		ClientSecret: githubClientSecret,
		Endpoint: oauth2.Endpoint{
			AuthURL:  "https://github.com/login/oauth/authorize",
			TokenURL: "https://github.com/login/oauth/access_token",
		},
		RedirectURL: redirectUrl,
		Scopes:      scopes,
	}

}

func githubLoginHandler(w http.ResponseWriter, r *http.Request) {

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
		sessionManager.Put(r.Context(), "platform", "github")

		http.Redirect(w, r, githubAuthConfig.AuthCodeURL(state), http.StatusFound)
	}
}

func googleLoginHandler(w http.ResponseWriter, r *http.Request) {

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
		sessionManager.Put(r.Context(), "platform", "google")

		http.Redirect(w, r, googleAuthConfig.AuthCodeURL(state), http.StatusFound)
	}
}

func googleOauthHandler(w http.ResponseWriter, r *http.Request) {
	if sessionManager.GetString(r.Context(), "platform") != "google" {
		http.Error(w, "This path is reserved for Google Oauth", http.StatusForbidden)
	} else {
		if sessionManager.GetInt(r.Context(), "id") != 0 {
			http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
		} else {
			state := sessionManager.GetString(r.Context(), "state")
			if r.URL.Query().Get("state") != state {
				http.Error(w, "state did not match", http.StatusBadRequest)
				return
			}
			oauth2Token, err := googleAuthConfig.Exchange(ctx, r.URL.Query().Get("code"))

			if err != nil {
				http.Error(w, "Failed to exchange token: "+err.Error(), http.StatusInternalServerError)
				return
			}
			log.Println("Reading Google OauthToken")

			res2B, _ := json.Marshal(oauth2Token)
			log.Println(string(res2B))

			userInfo, err := googleProvider.UserInfo(ctx, oauth2.StaticTokenSource(oauth2Token))
			if err != nil {
				http.Error(w, "Failed to get userinfo: "+err.Error(), http.StatusInternalServerError)
				return
			}

			log.Println("Google User Sub", userInfo.Subject)
			log.Println("Google User profile", userInfo.Profile)
			log.Println("Google User email", userInfo.Email)

			sessionManager.Put(r.Context(), "login", userInfo.Email)
			sessionManager.Put(r.Context(), "id", userInfo.Subject)

			token, expiry, err := sessionManager.Commit(r.Context())

			if err != nil {
				http.Error(w, err.Error(), http.StatusUnauthorized)
			}

			sessionManager.WriteSessionCookie(r.Context(), w, token, expiry)
			http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
		}
	}
}

func githubOauthHandler(w http.ResponseWriter, r *http.Request) {

	if sessionManager.GetString(r.Context(), "platform") != "github" {
		http.Error(w, "This path is reserved for Github Oauth", http.StatusForbidden)
	} else {
		if sessionManager.GetInt(r.Context(), "id") != 0 {
			http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
		} else {
			state := sessionManager.GetString(r.Context(), "state")

			if r.URL.Query().Get("state") != state {
				http.Error(w, "state did not match", http.StatusBadRequest)
				return
			}

			oauth2Token, err := githubAuthConfig.Exchange(ctx, r.URL.Query().Get("code"))

			if err != nil {
				http.Error(w, "Failed to exchange token: "+err.Error(), http.StatusInternalServerError)
				return
			}

			log.Println("Reading Github OauthToken")

			res2B, _ := json.Marshal(oauth2Token)
			log.Println(string(res2B))

			sessionManager.Put(r.Context(), "oauthtoken", oauth2Token.AccessToken)

			userDetails, err := githubGetUserDetails(oauth2Token.AccessToken)
			if err != nil {
				http.Error(w, err.Error(), http.StatusUnauthorized)
			}

			res2C, _ := json.Marshal(userDetails)
			log.Println(string(res2C))

			sessionManager.Put(r.Context(), "login", userDetails.Login)
			sessionManager.Put(r.Context(), "id", userDetails.Id)

			token, expiry, err := sessionManager.Commit(r.Context())

			if err != nil {
				http.Error(w, err.Error(), http.StatusUnauthorized)
			}

			sessionManager.WriteSessionCookie(r.Context(), w, token, expiry)

			http.Redirect(w, r, "/", http.StatusTemporaryRedirect)

		}
	}

}

func githubGetUserDetails(token string) (User, error) {

	var user User
	req, err := http.NewRequest("GET", "https://api.github.com/user", nil)

	if err != nil {
		return user, err
	}

	req.Header.Add("Authorization", "Bearer "+token)
	client := &http.Client{}
	resp, err := client.Do(req)

	if err != nil {
		return user, err
	}
	defer resp.Body.Close()

	json.NewDecoder(resp.Body).Decode(&user)

	return user, nil

}
