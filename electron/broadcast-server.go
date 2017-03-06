package main

import (
	"sync"

	"fmt"

	"net/http"

	"golang.org/x/net/websocket"
)

type Broadcaster struct {
	sync.RWMutex
	clients []*websocket.Conn
}

func (b *Broadcaster) Handler(conn *websocket.Conn) {
	b.Lock()
	b.clients = append(b.clients, conn)
	fmt.Printf("Client connected: %d clients\n", len(b.clients))
	b.Unlock()

	var message interface{}
	for {
		err := websocket.JSON.Receive(conn, &message)
		if err != nil {
			fmt.Printf("Failed to read from websocket: %s\n", err.Error())

			b.Lock()
			for i, c := range b.clients {
				if c == conn {
					b.clients[i] = b.clients[len(b.clients)-1]
					b.clients = b.clients[:len(b.clients)-1]
					fmt.Printf("Client disconnected: %d clients\n", len(b.clients))
					break
				}
			}
			b.Unlock()
			return
		}

		b.RLock()
		for _, c := range b.clients {
			if c != conn {
				websocket.JSON.Send(c, message)
			}
		}
		b.RUnlock()
	}
}

func main() {
	b := Broadcaster{}
	http.Handle("/ws", websocket.Handler(b.Handler))
	http.Handle("/", http.FileServer(http.Dir(".")))
	http.ListenAndServe(":3434", nil)
}
