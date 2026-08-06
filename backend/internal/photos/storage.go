package photos

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Uploader interface {
	Upload(ctx context.Context, path, contentType string, body io.Reader) (string, error)
}

// S3Storage sube fotos a un bucket S3-compatible (Railway Object Storage).
// El bucket es privado (sin lectura pública ni bucket policy), así que las
// URLs que devuelve Upload apuntan al proxy propio del backend (ver Proxy),
// que genera una presigned GET fresca en cada request.
type S3Storage struct {
	Client    *minio.Client
	Bucket    string
	PublicURL string // ej. https://tcgmarketcordoba.up.railway.app (sin / final)
}

func NewS3Storage(endpoint, accessKey, secretKey, bucket, publicURL string) (*S3Storage, error) {
	endpoint = strings.TrimPrefix(strings.TrimPrefix(endpoint, "https://"), "http://")
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: true,
	})
	if err != nil {
		return nil, err
	}
	return &S3Storage{
		Client:    client,
		Bucket:    bucket,
		PublicURL: strings.TrimSuffix(publicURL, "/"),
	}, nil
}

func (s *S3Storage) Upload(ctx context.Context, path, contentType string, body io.Reader) (string, error) {
	_, err := s.Client.PutObject(ctx, s.Bucket, path, body, -1, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s/photos/%s", s.PublicURL, path), nil
}

// Proxy sirve GET /photos/{path...}: redirige a una presigned GET del
// bucket privado, generada al momento. La URL guardada en la DB
// (PublicURL + "/photos/" + path) es estable aunque la presignada expire,
// porque se regenera en cada request.
type Proxy struct {
	Client *minio.Client
	Bucket string
}

func (p *Proxy) Serve(w http.ResponseWriter, r *http.Request) {
	path := r.PathValue("path")
	if path == "" || strings.Contains(path, "..") {
		http.NotFound(w, r)
		return
	}
	u, err := p.Client.PresignedGetObject(r.Context(), p.Bucket, path, 15*time.Minute, nil)
	if err != nil {
		http.Error(w, "error interno", http.StatusBadGateway)
		return
	}
	http.Redirect(w, r, u.String(), http.StatusFound)
}
