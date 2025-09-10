variable "BUILD_DATE" {
  default = ""
}

variable "BUILD_VERSION" {
  default = "latest"
}

variable "REGISTRY" {
  default = "localhost:5002"
}

group "default" {
  targets = ["vote", "result", "worker"]
}

target "vote" {
  context = "./vote"
  dockerfile = "Dockerfile"
  tags = [
    "${REGISTRY}/hostk8s-vote:latest",
    "${REGISTRY}/hostk8s-vote:${BUILD_VERSION}"
  ]
  target = "final"
  platforms = ["linux/amd64"]
  output = ["type=image,push=true"]
  labels = {
    "org.opencontainers.image.created" = "${BUILD_DATE}"
    "org.opencontainers.image.version" = "${BUILD_VERSION}"
    "org.opencontainers.image.title" = "HostK8s Voting App - Vote Service"
  }
}

target "result" {
  context = "./result"
  dockerfile = "Dockerfile"
  tags = [
    "${REGISTRY}/hostk8s-result:latest",
    "${REGISTRY}/hostk8s-result:${BUILD_VERSION}"
  ]
  platforms = ["linux/amd64"]
  output = ["type=image,push=true"]
  labels = {
    "org.opencontainers.image.created" = "${BUILD_DATE}"
    "org.opencontainers.image.version" = "${BUILD_VERSION}"
    "org.opencontainers.image.title" = "HostK8s Voting App - Result Service"
  }
}

target "worker" {
  context = "./worker"
  dockerfile = "Dockerfile"
  tags = [
    "${REGISTRY}/hostk8s-worker:latest",
    "${REGISTRY}/hostk8s-worker:${BUILD_VERSION}"
  ]
  platforms = ["linux/amd64"]
  output = ["type=image,push=true"]
  labels = {
    "org.opencontainers.image.created" = "${BUILD_DATE}"
    "org.opencontainers.image.version" = "${BUILD_VERSION}"
    "org.opencontainers.image.title" = "HostK8s Voting App - Worker Service"
  }
}
