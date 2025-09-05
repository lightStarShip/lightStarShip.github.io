package main

import (
	"fmt"
	"net"
	"net/http"
	"os"
)

func main() {
	mux := http.NewServeMux()
	mux.Handle("/", welcome())

	server := &http.Server{Handler: mux}
	l, err := net.Listen("tcp4", "0.0.0.0:8888")
	if err != nil {
		panic(err)
	}

	err = server.Serve(l)
	if err != nil {
		panic(err)
	}
}

type UriInfos struct {
	Content string
	Type    string
}

var fileMap = map[string]UriInfos{
	"/version.js":          {"../version.js", "application/json"},
	"/rule.txt":            {"../rule.txt", "application/text"},
	"/must_hit.txt":        {"../must_hit.txt", "application/text"},
	"/bypass.txt":          {"../bypass.txt", "application/text"},
	"/ruleVer.js":          {"../ruleVer.js", "application/json"},
	"/nodeConfig.json":     {"../nodeConfig.json", "application/json"},
	"/priceConfig.json":    {"../priceConfig.json", "application/json"},
	"/theBigDipper.dmg":    {"../theBigDipper.dmg", "application/octet-stream"},
	"/TweetCatApp.dmg":     {"../TweetCatApp.dmg", "application/octet-stream"},
	"/star.apk":            {"../star.apk", "application/octet-stream"},
	"/TheBigDipperVPN.apk": {"../TheBigDipperVPN.apk", "application/octet-stream"},
	"/TBDSetup.rar":        {"../TBDSetup.rar", "application/octet-stream"},
}

func welcome() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		dest, ok := fileMap[r.RequestURI]
		if !ok {
			_, _ = fmt.Fprint(w, "welcome to config service")
			return
		}
		bts, _ := os.ReadFile(dest.Content)
		w.Header().Add("Content-Type", dest.Type)
		_, _ = w.Write(bts)
		fmt.Println("success for:", dest.Content, dest.Type)
	})
}
