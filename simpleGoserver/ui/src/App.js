import logo from './logo.svg';
import './App.css';
import UserInfo from './components/userInfo';
import Posts from './components/posts';
import FileUploadComponent from './components/fileupload';
import { useState, useEffect } from 'react';
import { Nav, NavItem, Navbar } from 'react-bootstrap';

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
        <Nav>
          <NavItem>
            <UserInfo sub={userInfo.sub} login={userInfo.login} ></UserInfo>
          </NavItem>
          <NavItem>
          <div >
            <p>
              Edit <code>src/App.js</code> and save to reload.
            </p>
            <a
              className="App-link"
              href="https://reactjs.org"
              target="_blank"
              rel="noopener noreferrer"
            >
              Learn React
            </a>
          </div>
    </NavItem>
      </Nav>
      
      </div>
    )
  }

  return (
    
    <div>
      <Nav>
        <NavItem>
          <UserInfo sub={userInfo.sub} login={userInfo.login} ></UserInfo>
        </NavItem>
      <NavItem>
      <div >
        <p>
          Edit <code>src/App.js</code> and save to reload.
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </div>
    </NavItem>
      </Nav>
      <Posts></Posts>
      <FileUploadComponent></FileUploadComponent>
    </div>
  );
}

export default App;
