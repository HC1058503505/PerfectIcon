//
//  PerfectMongo.swift
//  PerfectIcon
//
//  Created by UltraPower on 2017/4/7.
//
//

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import MySQL

fileprivate let mysql_host = "localhost"
fileprivate let mysql_user = "root"
fileprivate let mysql_pwd = ""
fileprivate let mysql_db = "test"
fileprivate let mysql_socket = "/tmp/mysql.sock"

func resignRoutes() {
    routes.add(method: .get, uri: "/") { (req, resp) in
        resp.appendBody(string: "welcome!")
        resp.completed()
    }
    
    routes.add(method: .get, uri: "hello") { (req, resp) in
        resp.appendBody(string: "hello houcong!")
        resp.completed()
    }
    
    routes.add(method: .get, uri: "/files/**") { (req, resp) in
        
        req.path = req.urlVariables[routeTrailingWildcardKey]!
        let handler = StaticFileHandler(documentRoot: server.documentRoot)
        
        handler.handleRequest(request: req, response: resp)
    }
    
    routes.add(method: .post, uri: "/files/personInfo") { (req, resp) in
        let params:[(String,String)] = req.postParams
        
        var json = "{"
        
        for param in params {
            let str = "\"" + param.0 + "\"" + ":" + "\"" + param.1 + "\"" + ","
            json.append(str)
        }
        
        
        let range = Range<String.Index>(json.index(json.endIndex, offsetBy: -1)..<json.endIndex)
        
        json.replaceSubrange(range, with: "}")
        
        let thisFile = File(server.documentRoot + "/info.txt")
        do {
            try thisFile.open(.readWrite)
            try thisFile.write(string: json)
        }catch {
            print(error)
        }
        thisFile.close()
        
        resp.appendBody(string: json)
        resp.completed()
    }
    
    routes.add(method: .get, uri: "/files/personInfo") { (req, resp) in
        req.path = "/info.txt"
        let handler = StaticFileHandler(documentRoot: server.documentRoot)
        handler.handleRequest(request: req, response: resp)
    }
    
    routes.add(method: .get, uri: "/mysql") { (req, resp) in
        let dataMysql = MySQL()  // create an instance of mySQL to work with
        
        // connect to database
        let connect = dataMysql.connect(host: mysql_host, user: mysql_user, password: mysql_pwd, db: mysql_db, socket: mysql_socket)
        
        guard connect else {
            // failed to connect database
            print(dataMysql.errorMessage())
            return
        }
        
        defer {
            // close database when already used
            dataMysql.close()
        }
        
        // create tables
        let sql = "create table if not exists person (id integer primary key AUTO_INCREMENT, name varchar(50), age int)"
        if (dataMysql.query(statement: sql)){
            print("Success")
            resp.appendBody(string: "connect mysql success!")
            resp.completed()
        }
    }
    
    routes.add(method: .get, uri: "/mysql/add") { (req, resp) in
        let dataMysql = MySQL()
        
        let connect = dataMysql.connect(host: mysql_host, user: mysql_user, password: mysql_pwd, db: mysql_db, socket: mysql_socket)
        guard connect else {
            print(dataMysql.errorMessage())
            return
        }
        defer {
            dataMysql.close()
        }
        
        let name:String = req.param(name: "name") ?? ""
        let age:Int = Int(req.param(name: "age") ?? "0")!
        
        let sql = "insert into person (name,age) values (\(name),\(age))"
        
        if (dataMysql.query(statement: sql)){
            resp.appendBody(string: "insert person success")
        } else {
            resp.appendBody(string: "fail to insert person")
        }
        resp.completed()
    }
    
    routes.add(method: .get, uri: "/mysql/query") { (req, resp) in
        let dataMysql = MySQL()
        let connect = dataMysql.connect(host: mysql_host, user: mysql_user, password: mysql_pwd, db: mysql_db, socket: mysql_socket)
        
        guard connect else {
            resp.appendBody(string: dataMysql.errorMessage())
            resp.completed()
            return
        }
        
        defer {
            dataMysql.close()
        }
        
        let sql = "select * from person"
        if(dataMysql.query(statement: sql)){
            let results = dataMysql.storeResults()
            var person:[[String:Any]] = [[String:Any]]()
            results?.forEachRow(callback: { (element) in
                let person_id:Int = Int(element[0] ?? "0")!
                let person_name:String = element[1]!
                let person_age:Int = Int(element[2] ?? "0")!
                person.append(["id":person_id,"name":person_name,"age":person_age])
            })
            
            let respResult = ["psersons":person]
            do {
                try resp.appendBody(string: respResult.jsonEncodedString())
            } catch {
                print(error)
            }
        } else {
            resp.appendBody(string: "操作出现错误")
        }
        resp.completed()
    }

    
    // 文件上传
    routes.add(method: .post, uri: "/upload") { (req, resp) in
        
        // 通过操作fileUploads数组来掌握文件上传的情况
        // 如果这个POST请求不是分段multi-part类型，则该数组内容为空
        if let uploads = req.postFileUploads , uploads.count > 0 {
            // 创建文件保存路径
            let fileDir = Dir(Dir.workingDir.path + "files")
            do {
                try fileDir.create()
            } catch {
                resp.appendBody(string: "create failed")
                print(error)
            }
            
            // 创建一个字典数组用于检查已经上载的内容
            var ary = [[String:Any]]()
            
            for upload in uploads {
                ary.append([
                    "fieldName": upload.fieldName,  //字段名
                    "contentType": upload.contentType, //文件内容类型
                    "fileName": upload.fileName,    //文件名
                    "fileSize": upload.fileSize,    //文件尺寸
                    "tmpFileName": upload.tmpFileName   //上载后的临时文件名
                    ])
                
                // 获取上传的临时文件
                let thisFile = File(upload.tmpFileName)
                
                do {
                    let _ = try thisFile.moveTo(path: fileDir.path + upload.fileName, overWrite: true)
                } catch {
                    resp.appendBody(string: "remove failed")
                    print(error)
                }
                
            }
            
            
            resp.appendBody(string: "upload success")
            
            
        } else {
            resp.appendBody(string: "upload fail")
            
        }
        resp.completed()
    }
    
    
    routes.add(method: .get, uri: "/download/**") { (req, resp) in
        req.path = req.urlVariables[routeTrailingWildcardKey]!
        let handler = StaticFileHandler(documentRoot: Dir.workingDir.path + "files")
        
        handler.handleRequest(request: req, response: resp)
    }
    server.addRoutes(routes)
}
