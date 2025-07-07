import './App.css';
import UserInfo from './components/userInfo';
import Posts from './components/posts';
import BannerDisplay from "./components/banner"
import { useState, useEffect } from 'react';

const fetchUser = async () => {
    const response = await fetch('userinfo'); 
    console.log("waiting for await")
    if (!response.ok) {
      console.log("User is unauthorized Code: ",response.status)
      return {
        sub : "",
        login: ""
      }
    }
    return await response.json();
};



function App() {

  const [userInfo, setUserInfo] = useState({
    sub : "",
    login: ""
  });


  useEffect(() => {
    
    if (userInfo.sub === "") {
      console.log("Inside useEffect")
      fetchUser().then((res)=> {
        console.log("Inside then")
        setUserInfo(res);
      }).catch((err)=> {
        console.log(err)
      })
      console.log("After fetchUser")
    } 
  }, []); 

  if(userInfo.sub === "") {
    return (
      <div>
          <BannerDisplay></BannerDisplay>
          <UserInfo sub={userInfo.sub} login={userInfo.login} ></UserInfo>
      </div>
    )
  }

  return (
    
    <div>
        <BannerDisplay></BannerDisplay>
        <UserInfo sub={userInfo.sub} login={userInfo.login} ></UserInfo>
        <Posts></Posts>
    </div>
  );
}

export default App;
