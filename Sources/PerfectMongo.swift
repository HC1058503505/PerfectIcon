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
import MongoDB
import MySQL
import SQLite

fileprivate let mysql_host = "localhost"
fileprivate let mysql_user = "root"
fileprivate let mysql_pwd = ""
fileprivate let mysql_db = "test"
fileprivate let mysql_socket = "/tmp/mysql.sock"

fileprivate let sqlite_dbpath = "./db/database"
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
    
    routes.add(method: .get, uri: "/mongodb/test") { (req, resp) in
        resp.appendBody(string: collectionName(name: "test"))
        resp.completed()
    }
    
    routes.add(method: .get, uri: "/mongodb/info") { (req, resp) in
        
        resp.appendBody(string: collectionName(name: "info"))
        resp.completed()
        
    }
    
    
    routes.add(method: .post, uri: "/mongodb/add/info") { (req, resp) in
        do {
            // 启动数据库
            let mongodb = try MongoClient(uri: "mongodb://localhost")
            
            let database = mongodb.getDatabase(name: "test")
            
            let collection = database.getCollection(name: "info")
            
            defer {
                collection?.close()
                database.close()
                mongodb.close()
            }
            
            let params:[(String,String)] = req.postParams
            
            var json = "{"
            
            for param in params {
                let str = "\"" + param.0 + "\"" + ":" + "\"" + param.1 + "\"" + ","
                json.append(str)
            }
            
            
            let range = Range<String.Index>(json.index(json.endIndex, offsetBy: -1)..<json.endIndex)
            
            json.replaceSubrange(range, with: "}")
            
            let bson:BSON = try BSON(json: json)
            
            let result = collection?.insert(document: bson)
            
            resp.appendBody(string: result.debugDescription)
            resp.completed()
            
            
        } catch {
            print(error)
        }
        
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
    
    routes.add(method: .get, uri: "/sqlite3") { (req, resp) in
        
        do {
            let sqlite = try SQLite(sqlite_dbpath)
            
            defer {
                sqlite.close()
            }
            
            let sql = "create table if not exists person (id integer primary key AUTOINCREMENT, name text, age int)"
            try sqlite.execute(statement: sql)
            resp.appendBody(string: "Success!")
            resp.completed()
        } catch {
            print(error)
        }
    }
    
    routes.add(method: .get, uri: "/sqlite3/add") { (req, resp) in
        
        do {
            let sqlite = try SQLite(sqlite_dbpath)
            
            let person_name:String = req.param(name: "name") ?? ""
            let person_age:Int = Int(req.param(name: "age") ?? "0")!
            
            let sql = "insert into person (name, age) values (\(person_name),\(person_age))"
            try sqlite.execute(statement: sql)
            
            resp.appendBody(string: "Success!")
            resp.completed()
            
        } catch {
            print(error)
        }
    }
    
    routes.add(method: .get, uri: "/sqlite3/query") { (req, resp) in
        
        do {
            let sqlite = try SQLite(sqlite_dbpath)
            let sql = "select * from person"
            
            var result:[[String:Any]] = [[String:Any]]()
            
            try sqlite.forEachRow(statement: sql, handleRow: { (stmt, index) in
                let id:Int = stmt.columnInt(position: 0)
                let name:String = stmt.columnText(position: 1)
                let age:Int = stmt.columnInt(position: 2)
                let temp:[String:Any] = ["id":id,"name":name,"age":age]
                result.append(temp)
            })
            
            let lastResult = ["persons":result]
            try resp.appendBody(string: lastResult.jsonEncodedString())
            resp.completed()
        } catch {
            print(error)
        }
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


func collectionName(name:String) ->  String{
    do {
        // 1.连接数据库
        let client = try MongoClient(uri: "mongodb://localhost")
        // 1.获取数据库名字
        print(client.databaseNames())
        // 2.获取指定名称的数据库
        let db = client.getDatabase(name: "test")
        // 2.获取数据库collection名称
        print(db.collectionNames())
        // 3.获取指定名称collection
        let collection = db.getCollection(name: name)
        
        defer{
            // 在该请求结束时确保关闭collection,db,client
            collection?.close()
            db.close()
            client.close()
        }
        // 查询数据,返回查询游标
        let find = collection?.find(query: BSON())
        
        
        var arr:[[String:Any]] = [[String:Any]]()
        for fin in find! {
            let encode = fin.asString
            // json字符串解码
            let decode = try encode.jsonDecode() as! [String:Any]
            
            arr.append(decode)
        }
        
        let result = ["message":arr]
        // 字典数据编码为json字符串
        let jsonStr = try result.jsonEncodedString()
        
        return jsonStr
    } catch {
        print(error)
        return ""
    }
}
