package main

import (
	"fmt"
	"io"
	"os"

	"encoding/base64"

	"image"

	"image/jpeg"

	"os/exec"

	"time"

	"net/http"

	"strings"

	"github.com/kesarion/screenshot"
	"golang.org/x/net/websocket"
)

func main() {
	// http.Handle("/feed", websocket.Handler(ServeFeed))
	http.HandleFunc("/stream.webm", func(rw http.ResponseWriter, req *http.Request) {
		// fmt.Println(lowlatencyX(rw))
		// fmt.Println(livestreamX(rw))
		fmt.Println(dash(rw))
		// fmt.Println(streamXToVideo(rw))
		// fmt.Println(streamToVideo(produceImages(), rw))
	})
	http.Handle("/", http.FileServer(http.Dir("static")))
	http.ListenAndServe(":"+os.Getenv("PORT"), nil)
}

func ServeFeed(ws *websocket.Conn) {
	for img := range produceImages() {
		encoder := base64.NewEncoder(base64.StdEncoding, ws)

		err := jpeg.Encode(encoder, img, &jpeg.Options{Quality: jpeg.DefaultQuality})
		if err != nil {
			fmt.Print(err)
			return
		}
		encoder.Close()
		ws.Write([]byte("^^^"))
	}
}

func dash(output io.Writer) error {

	// text := `   -f x11grab -r 30 -s 1920x1080 -i :0.0

	// 			-pix_fmt yuv420p
	// 			-c:v libvpx-vp9
	// 			-s 1920x1080 -keyint_min 60 -g 60

	// 			-speed 6 -tile-columns 4 -frame-parallel 1 -threads 8 -static-thresh 0 -max-intra-rate 300 -deadline realtime -lag-in-frames 0 -error-resilient 1

	// 			-b:v 3000k
	// 			-f webm_chunk
	// 			-header ./webm_live/vid_360.hdr
	// 			-chunk_start_index 1
	// 			./webm_live/vid_360_%d.chk
	// 			`
	text := `   -f x11grab -r 30 -s 1920x1080 -i :0.0

				-pix_fmt yuv420p 
				-c:v libvpx-vp9 
				-s 1920x1080 -keyint_min 60 -g 60 

				-speed 6 -tile-columns 4 -frame-parallel 1 -threads 8 -static-thresh 0 -max-intra-rate 300 -deadline realtime -lag-in-frames 0 -error-resilient 1

				-b:v 3000k 
				-f webm_chunk 
				-header webm_live/vid_360.hdr
				-chunk_start_index 1 
				webm_live/vid_360_%d.chk 
				`
	// -c:a libvorbis
	// -b:a 128k -ar 44100
	// -f webm_chunk
	// -audio_chunk_duration 2000
	// -header ./webm_live/aud.hdr
	// -chunk_start_index 1
	// ./webm_live/aud_%d.chk
	//   `
	cmd := exec.Command("ffmpeg", strings.Fields(text)...)
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	go io.Copy(os.Stdout, stderr)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	err = cmd.Start()
	if err != nil {
		return err
	}

	_, err = io.Copy(output, stdout)
	cmd.Process.Kill()
	return err
}

func lowlatencyX(output io.Writer) error {
	cmd := exec.Command("ffmpeg",
		"-f", "x11grab", "-s", "1280x720", "-framerate", "30", "-i", ":0.0", "-c:v", "libx264",
		"-preset", "veryfast", "-tune", "zerolatency", "-pix_fmt", "yuv444p",
		"-x264opts", "crf=20:vbv-maxrate=3000:vbv-bufsize=100:intra-refresh=1:slice-max-size=1500:keyint=30:ref=1",
		"-f", "mpegts", "-",
	)
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	go io.Copy(os.Stdout, stderr)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	err = cmd.Start()
	if err != nil {
		return err
	}

	_, err = io.Copy(output, stdout)
	cmd.Process.Kill()
	return err
}

func livestreamX(output io.Writer) error {
	cmd := exec.Command("ffmpeg", "-f", "alsa",
		// "-ac", "2", "-i", "hw:0,0",
		"-framerate", "24",
		"-f", "x11grab",

		//"-video_size", "1280x720",
		"-i", ":0.0+0,0", "-c:v", "libvpx", "-preset", "veryfast",
		"-tune", "zerolatency",
		// "-maxrate", "960k", "-bufsize", "1800k",
		// "-g", "48",
		"-c:a", "libvorbis", "-b:a", "128k", "-ar", "44100",
		"-f", "webm", "-")
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	go io.Copy(os.Stdout, stderr)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	err = cmd.Start()
	if err != nil {
		return err
	}

	_, err = io.Copy(output, stdout)
	cmd.Process.Kill()
	return err
}

func streamXToVideo(output io.Writer) error {
	cmd := exec.Command("ffmpeg",
		"-f", "x11grab",
		"-video_size", "cif", "-r", "24", "-i", ":0.0",
		"-c:v", "libvpx", "-b:v", "1M", "-c:a", "libvorbis", "-f", "webm", "-",
	)
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	go io.Copy(os.Stdout, stderr)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	err = cmd.Start()
	if err != nil {
		return err
	}

	_, err = io.Copy(output, stdout)
	cmd.Process.Kill()
	return err
}

func streamToVideo(frames <-chan image.Image, output io.Writer) error {
	cmd := exec.Command("ffmpeg",
		"-f", "image2pipe",
		"-vcodec", "mjpeg", "-r", "24", "-i", "-",
		"-vcodec", "mpeg4", "-r", "24", "-qscale", "5", "-",
	)
	in, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	err = cmd.Start()
	if err != nil {
		return err
	}
	for img := range frames {
		err = jpeg.Encode(in, img, nil)
		if err != nil {
			return err
		}
	}
	return in.Close()
}

func produceImages() chan image.Image {
	out := make(chan image.Image)
	go func() {
		defer close(out)
		total := 0

		for range time.Tick(time.Millisecond * 16) {
			img, err := screenshot.CaptureScreen()
			if err != nil {
				fmt.Println(err)
				return
			}
			total++
			out <- img
			if total > 300 {
				break
			}
		}
	}()

	return out
}
