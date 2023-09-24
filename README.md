# cssml
CSS and HTML in one language.

### Quick Start
To get started create a file that ends with the `.cssml` extension; `index.cssml` for this example. Save this code to `index.cssml` (or to whatever you named the file on your system).
```css
html {
    > head {}
    > body {
        > h1 {
            font-family: "Comic Sans MS", Cursive, serif;
            "Hello World!"
        }
    }
}
```
Next compile the CSSML to an HTML file with the `cssml index.cssml` command. The above code will output this HTML to `index.html`.
```html
<!DOCTYPE html>
<html>
    <head>
        <style type="text/css">
            html {
                > body {
                    > h1 {
                        font-family: "Comic Sans MS", Cursive, serif;
                    }
                }
            }
        </style>
    </head>
    <body>
        <h1>
            Hello World
        </h1>
    </body>
</html>
```