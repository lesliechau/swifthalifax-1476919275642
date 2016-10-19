//  Author: Swift@IBM team 
/* This tutorial will walk through the procedure to create a new microservices REST API in the open source Swift programming language. Swift enables developers to extend the popular client side iOS language to the server side so developers and teams can use the same language end to end. 

    This REST API created will expose a GET operation which queries a
    backend Cloudant database and returns all the employee salary
    information. The backend empldb table in this Cloudant database has
    profile information for all employees, but the API will be built to
    return only a subset. 
*/

import Foundation
import Kitura
import SwiftyJSON
import CouchDB
import LoggerAPI
import CloudFoundryEnv
import HeliumLogger

let host = "ibmswift.cloudant.com"
let username = "ibmswift"
let password = "s3rv3rs1desw1ft"
let databaseName = "empldb"

typealias StringValuePair = [String : Any]

protocol StringValuePairConvertible {

    var stringValuePairs: StringValuePair {get}
}

extension Array where Element : StringValuePairConvertible {
    var stringValuePairs: [StringValuePair] {
        return self.map { $0.stringValuePairs }
    }
}

let connectionProperties = ConnectionProperties(
    host: host,
    port: 80,
    secured: false,
    username: username,
    password: password
)

struct Employee {
    let empno: String
    let firstName: String
    let lastName: String
    let salary: Int

    init(json: JSON) {
        empno = json["empno"].stringValue.capitalized
        firstName = json["firstnme"].stringValue.capitalized
        lastName = json["lastname"].stringValue.capitalized
        salary = json["salary"].intValue
    }
}

extension Employee: StringValuePairConvertible {
    var stringValuePairs: [String: Any] {
        return ["empno": self.empno,
                "firstName": self.firstName,
                "lastName": self.lastName,
                "salary": self.salary]
    }
}


let router = Router()

let cloudantClient = CouchDBClient(connectionProperties: connectionProperties)
let database = cloudantClient.database(databaseName)


router.get("/api/emplsalaries") { _, response, next in

    database.retrieveAll(includeDocuments: true) { json, error in
    
        guard let json = json else {
            response.status(.badRequest)
            return
        }

        let employees = json["rows"].map { _, row in
            return Employee.init(json: row["doc"])
        }

        response.status(.OK).send(json: JSON(employees.stringValuePairs))
        next()
    }

}


HeliumLogger.use()

do {
    let appEnv = try CloudFoundryEnv.getAppEnv()
    let port: Int = appEnv.port
    Log.info("Server will be started on '\(appEnv.url)'.")
    Kitura.addHTTPServer(onPort: port, with: router)
    Kitura.run()
} catch CloudFoundryEnvError.InvalidValue {
    Log.error("Oops... something went wrong. Server did not start!")
}

