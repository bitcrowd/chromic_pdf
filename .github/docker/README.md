# How to update

## Build new image for the CI

- Create a new Dockerfile, named `Dockerfile_${relevant suffix(es)}`
- Edit `.github/workflows/publish-image.yml` and add the suffixes to the `strategy.matrix.dockerfile` list
- Open your PR. The workflow `publish-image` should be triggered, and you should see in the Github Actions its status. If it's green, your image will be available in https://github.com/bitcrowd/chromic_pdf/pkgs/container/chromic_pdf-test-image

## Build new image for local test

```
cd .github/docker
<make your changes>
docker build -t bitcrowd/chromic_pdf-test-image:x.y.z .
```

## Test the image

By method of your choice. Disable the default seccomp profile. This will work for example:

```
docker run -it -v $(pwd):/src --rm --security-opt seccomp=unconfined bitcrowd/chromic_pdf-test-image:x.y.z
```

Inside container:

```
# there are other means of getting files into the container, but this is simple enough
$ cp -r /src .
$ cd src
$ mix deps.get
$ MIX_ENV=integration mix test
```
