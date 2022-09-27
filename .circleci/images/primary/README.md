# How to update

## Edit and build new image

```
cd .circleci/images/primary
<make your changes>
docker build -t maltoe/chromic-pdf-primary:x.y.z .
```

## Test the image

By method of your choice. Disable the default seccomp profile. This will work for example:

```
docker run -it -v $(pwd):/src --rm --security-opt seccomp=unconfined maltoe/chromic-pdf-primary:x.y.z
```

Inside container:

```
# there are other means of getting files into the container, but this is simple enough
$ cp -r /src .
$ cd src
$ mix deps.get
$ MIX_ENV=integration mix test
```

## Push new image to docker hub

First acquire the credentials from @maltoe.

```
docker login
docker push maltoe/chromic-pdf-primary:x.y.z
```

## Update the circleci config

in `.circleci/config.yml`
