# 🐳 Docker-Jenkins Android (based on Ubuntu)

![Version badge](https://img.shields.io/badge/version-1.0-green.svg)
![License badge](https://img.shields.io/badge/License-MIT-blue.svg)

Jenkins Docker Image for __Android CI__.

![jenkins-image](https://camo.githubusercontent.com/a5004ae5bffb9a59384514fd88d3f18c47e1e0373bfda94a18b422e4a164d399/68747470733a2f2f6a656e6b696e732e696f2f73697465732f64656661756c742f66696c65732f6a656e6b696e735f6c6f676f2e706e67)

# Fork base
[Jenkins Official Docker Image (in Github Repo)](https://github.com/jenkinsci/docker)

# Usage (with Docker CLI)
## Simply build your image

`docker build -t [Your image name] .`

## Simply run your image

`docker run -p 8080:8080 -p 50000:50000 -v ~/jenkins_home:/var/jenkins_home [Your image name]`

- It will automatically create a `jenkins_home` in your home directory for docker volume.

## Run with Container name (Optional)

`docker run --name [Your container name] -p 8080:8080 -p 50000:50000 -v ~/jenkins_home:/var/jenkins_home [Your image name]`

# Versions

## Jenkins 

[![Jenkins version badge](https://img.shields.io/badge/version-2.303.1-green.svg)](https://www.jenkins.io/download)

## Gradle
[![Gradle version badge](https://img.shields.io/badge/version-7.2-green.svg)](https://gradle.org/releases/)

## Android Command Line Tools - Linux
[![CLT version badge](https://img.shields.io/badge/version-7583922-green.svg)](https://developer.android.com/studio#command-tools)

## Android SDK
- Android API 30

- build-tools 30.0.3

If you want to add more Android API or build-tools, edit Dockerfile under __38-39__ lines. 
```dockerfile
38> RUN echo yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT "platform-tools" "build-tools;[build-tools-version]"
39> RUN echo yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT "platform-tools" "platforms;[android-api-version]" 
```