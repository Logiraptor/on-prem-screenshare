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
	b.sendAll(struct {
		NumClients int `json:"numClients"`
	}{NumClients: len(b.clients)})
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
					b.sendAll(struct {
						NumClients int `json:"numClients"`
					}{NumClients: len(b.clients)})
					break
				}
			}
			b.Unlock()
			return
		}

		b.RLock()
		b.sendFrom(conn, message)
		b.RUnlock()
	}
}

func (b *Broadcaster) sendFrom(conn *websocket.Conn, msg interface{}) {
	for _, c := range b.clients {
		if c != conn {
			websocket.JSON.Send(c, msg)
		}
	}
}

func (b *Broadcaster) sendAll(msg interface{}) {
	for _, c := range b.clients {
		websocket.JSON.Send(c, msg)
	}
}

type RoomServer struct {
	sync.Mutex
	rooms map[string]*Broadcaster
}

func (rs *RoomServer) handler(conn *websocket.Conn) {
	roomName := conn.Request().FormValue("room")
	rs.Lock()
	if _, ok := rs.rooms[roomName]; !ok {
		fmt.Println("Creating room", roomName)
		rs.rooms[roomName] = &Broadcaster{}
	}
	handler := rs.rooms[roomName]
	rs.Unlock()

	handler.Handler(conn)
}

func NewRoomServer() *RoomServer {
	return &RoomServer{
		rooms: make(map[string]*Broadcaster),
	}
}

func main() {
	rs := NewRoomServer()
	http.Handle("/ws", websocket.Handler(rs.handler))
	http.Handle("/", http.FileServer(http.Dir(".")))
	http.ListenAndServe(":3434", nil)
}
