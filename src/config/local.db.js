import mysql from 'mysql2'
import dotenv from 'dotenv'
dotenv.config()
const db=mysql.createConnection({
    host:process.env.db_host || 'localhost',
    user: process.env.db_user || 'root',
    password:process.env.db_password || '',
    database:process.env.db_name || 'bookit',
    port:process.env.db_port || 3306
})
db.connect((err)=>{
if(err){
    console.error("connection faild",err)
}
else{
    console.log("connected")
}
})
module.exports=db