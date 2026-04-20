import sequelize from './src/config/db.js';
import './src/app.js';

sequelize.authenticate()
.then(()=> sequelize.sync())
.then(()=>{
    // The app is started in src/app.js
    console.log('database connected');
})
.catch((error)=>{
    console.error("failed to connect ", error)
    process.exit(1)
})