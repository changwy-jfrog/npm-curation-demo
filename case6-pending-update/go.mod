// [DEMO] Case 6: Package Pending Update (Go) — google.golang.org/grpc@v1.81.0
// Ecosystem: Go
// Package: google.golang.org/grpc@v1.81.0
// Condition: Package Pending Update — version under security review
// Risk: Using a version that has been superseded by a safer release
// Action: Blocked by JFrog Curation | Safe version: google.golang.org/grpc@v1.80.0
module demo-case6-pending-update

go 1.21

require google.golang.org/grpc v1.81.0
