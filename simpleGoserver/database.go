package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/go-sql-driver/mysql"
)

type DbPost struct {
	ID     int64
	Body   string
	Userid string
}

var (
	db      *sql.DB
	db_pass string
	db_host = os.Getenv("DB_HOST")
)

func dbconnect() {

	paramName := "kube_db_secret"
	withDecryption := true

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	ssmClient := ssm.NewFromConfig(cfg)

	input := &ssm.GetParameterInput{
		Name:           &paramName,
		WithDecryption: &withDecryption,
	}

	result, err := ssmClient.GetParameter(context.TODO(), input)
	if err != nil {
		log.Fatalf("failed to get parameter, %v", err)
	}

	if result.Parameter != nil {
		fmt.Println("Parameter Value:", *result.Parameter.Value)
		db_pass = *result.Parameter.Value
	} else {
		fmt.Println("Parameter not found.")
	}
	// Capture connection properties.

	dbcfg := mysql.NewConfig()
	dbcfg.User = "admin"
	dbcfg.Passwd = db_pass
	dbcfg.Net = "tcp"
	dbcfg.Addr = db_host + ":3306"
	dbcfg.DBName = "posts"

	// Get a database handle.
	var dberr error
	db, dberr = sql.Open("mysql", dbcfg.FormatDSN())
	if dberr != nil {
		log.Fatal(err)
	}

	pingErr := db.Ping()
	if pingErr != nil {
		log.Fatal(pingErr)
	}
	fmt.Println("Connected!")
}

func getdbPostsByUserId(userId string) ([]DbPost, error) {

	var dbposts []DbPost

	rows, err := db.Query("SELECT * FROM postdata WHERE userid = ?", userId)
	if err != nil {
		return nil, fmt.Errorf("postsByUser %q: %v", userId, err)
	}
	defer rows.Close()

	for rows.Next() {
		var dbpost DbPost
		if err := rows.Scan(&dbpost.ID, &dbpost.Body, &dbpost.Userid); err != nil {
			return nil, fmt.Errorf("postsByUser %q: %v", userId, err)
		}
		dbposts = append(dbposts, dbpost)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("postsByUser %q: %v", userId, err)
	}
	return dbposts, nil
}

func getdbPostsBypostId(id int) (DbPost, error) {

	var dbpost DbPost

	rows, err := db.Query("SELECT * FROM postdata WHERE id = ?", id)
	if err != nil {
		return dbpost, fmt.Errorf("postsByID %q: %v", id, err)
	}
	defer rows.Close()

	if rows.Next() {
		if err := rows.Scan(&dbpost.ID, &dbpost.Body, &dbpost.Userid); err != nil {
			return dbpost, fmt.Errorf("postsByID %q: %v", id, err)
		}
	} else {
		return dbpost, fmt.Errorf("no post with id found %q: %v", id, err)
	}

	return dbpost, nil
}

func adddbPost(dbpost DbPost) (int64, error) {
	result, err := db.Exec("INSERT INTO postdata (body, userid) VALUES (?, ?)", dbpost.Body, dbpost.Userid)
	if err != nil {
		return 0, fmt.Errorf("addPost: %v", err)
	}
	id, err := result.LastInsertId()
	if err != nil {
		return 0, fmt.Errorf("addPost: %v", err)
	}
	return id, nil
}

func deldbPost(id int) (bool, error) {
	result, err := db.Exec("DELETE FROM postdata WHERE id = ?", id)
	if err != nil {
		return false, fmt.Errorf("DelPost: %v", err)
	}
	_, err2 := result.RowsAffected()
	if err2 != nil {
		return false, fmt.Errorf("DelPost: %v", err2)
	}
	return true, nil
}
