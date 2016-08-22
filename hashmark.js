const fs = require('fs')
const path = require('path')
const md5File = require('md5-file')

const content = {
  html: ''
}

fs.readFile(path.join(__dirname, '/public/index.html'), 'utf8', function (err, html) {
  if (err) console.error(err)
  const cssFiles = path.join(__dirname, '/public/css/')
  const imageFiles = path.join(__dirname, '/public/imgs/')
  const jsFiles = path.join(__dirname, '/public/js/')
  content.html = html
  rename(cssFiles, '.css')
  // rename(imageFiles, '.svg')
  // rename(jsFiles, '.js')
})

function rename (filesPath, ext) {
  fs.readdir(filesPath, (err, files) => {
    if (err) {
      console.error(err)
      return
    }

    files.forEach(function (filePath) {
      md5File(path.join(filesPath, filePath), (err, hash) => {
        if (err) throw err
        let pathNew = path.join(filesPath, filePath) + ''
        let newFilePath = filePath.replace(ext, `-${hash}${ext}`)
        content.html = content.html.replace(filePath, newFilePath)

        pathNew = pathNew.replace(ext, `-${hash}${ext}`)
        fs.writeFile(path.join(__dirname, '/public/index.html'), content.html)
        fs.rename(path.join(filesPath, filePath), pathNew, function (err) {
          if (err) console.error(err)
        })
      })
    })
  })
}
