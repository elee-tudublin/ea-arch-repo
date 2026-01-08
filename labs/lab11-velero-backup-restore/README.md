# Lab 11 — DR and backup with Velero + MinIO

## Introduction

In this lab you will install Velero+MinIO and perform backup/restore.

## Getting started

    make platform-velero
    kubectl get pods -n velero

Note: this lab requires the velero CLI installed in your VM.

## Part 1 — Backup

    velero backup create openchat-dev --include-namespaces openchat-dev
    velero backup get
    velero backup describe openchat-dev

## Part 2 — Restore test

    kubectl delete namespace openchat-dev
    velero restore create --from-backup openchat-dev
    kubectl get ns | grep openchat-dev
    kubectl get pods -n openchat-dev

## Exercises

1) Define RTO/RPO for OpenChat and justify.
2) Sustainability prompt: how do you right-size DR to risk?

## Extensions (optional) — DR test evidence

Add a DR evidence section to your notes:
- backup start time and end time
- restore start time and end time
- any manual steps required
- one risk discovered during the test and a mitigation

