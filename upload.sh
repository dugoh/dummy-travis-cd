#!/bin/bash
#Nothing yet
index() {
    echo "<HTML><HEAD><TITLE>LINKS</TITLE></HEAD><BODY><ul>" >index.html
    for file in $(ls|egrep -v "index.html| "); do \
        (\
            printf '<li><a href="'; \
            printf "${file}";       \
            printf '">';            \
            printf "${file}";       \
            printf '</a></li>\n'    \
        )>>index.html;              \
    done
    echo "</ul></BODY></HTML>" >>index.html
}

push() {
    GHP_URL=https://${GHP_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git
    git init
    git config user.name "${USER}"
    git config user.email "${GHP_MAIL}"
    git add .
    git commit -m "Deploy to GitHub Pages"
    git push --force --quiet "${GHP_URL}" master:gh-pages
}

## Push to gh-pages
mkdir gh-pages
cd gh-pages
cp ../1.cast ./
mv ../FLOPPY.img ./
mv ../disk.img ./
bzip2 --best disk.img
split -b 50m "disk.img.bz2" "disk.part-"
rm disk.img.bz2
index
push
exit 0
