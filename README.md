# gsmake.golang
The gsmake golang project plugin

#usage

editor .gsmake.json file add follow lines:

```json
{
    "import":[
        {"name":"github.com/gsdocker/golang","domain":"task","version":"v2.0"}
    ]
}
```

##task:compile and task:test

with property *gsmake.golang.binary* and property "gsmake.golang.test" you can define subdirs to be build or test :


```json
"properties":{
    "gsmake.golang.binary" :{
        "test" : "./test"
    },

    "gsmake.golang.test" :[
        {"dir":"./test","flags":"-bench ."}
    ]
}
```

**gsmake.golang.binary#key** :the generate binary name
**gsmake.golang.test#value** :the go build running directory

**gsmake.golang.test#dir** :command go test running directory
**gsmake.golang.test#flags** :define go test flags


the binary output directory is ${packagedir}/bin
