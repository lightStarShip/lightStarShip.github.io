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

var fileMap = map[string]string{
	"/version.js":       "../version.js",
	"/rule.txt":         "../rule.txt",
	"/must_hit.txt":     "../must_hit.txt",
	"/bypass.txt":       "../bypass.txt",
	"/ruleVer.js":       "../ruleVer.js",
	"/nodeConfig.json":  "../nodeConfig.json",
	"/priceConfig.json": "../priceConfig.json",
}

func welcome() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		path, ok := fileMap[r.RequestURI]
		if !ok {
			_, _ = fmt.Fprint(w, "welcome to config service")
			return
		}
		bts, _ := os.ReadFile(path)
		_, _ = w.Write(bts)
		fmt.Println("success for:", path)
	})
}
