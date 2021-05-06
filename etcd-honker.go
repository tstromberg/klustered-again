package main


func connect(ca string, cert string, key string, ip string, port int) {



	cert, err := tls.LoadX509KeyPair("client.crt", "client.key")
	+       if err != nil {
	+               log.Fatal(err)
	+       }
	+
			client := &http.Client{
					Transport: &http.Transport{
							TLSClientConfig: &tls.Config{
									RootCAs:      caCertPool,
	+                               Certificates: []tls.Certificate{cert},
							},
					},
			}

func main() {
	connect(os.Args(1))
