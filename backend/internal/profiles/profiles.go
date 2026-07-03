package profiles

import "errors"

var ErrUsernameTaken = errors.New("username taken")

type Profile struct {
	ID       string  `json:"id"`
	Username string  `json:"username"`
	CityID   *string `json:"city_id"`
	CityName *string `json:"city_name"`
}

type ContactMethod struct {
	ID    string `json:"id"`
	Type  string `json:"type"`
	Value string `json:"value"`
}

type City struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}
