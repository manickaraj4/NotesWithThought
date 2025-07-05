import logo from './logo.svg';
import './App.css';
import UserInfo from './components/userInfo';
import Posts from './components/posts';
import { useState, useEffect } from 'react';
import { Nav, NavItem, Navbar } from 'react-bootstrap';

const fetchUser = async () => {
    const response = await fetch('/userinfo'); 
    console.log("waiting for await")
    if (!response.ok) {
      console.log("User is unauthorized Code: ",response.status)
      return {
        id : 0,
        login: ""
      }
    }
    return await response.json();
};



function App() {

  const [userInfo, setUserInfo] = useState({
    id : 0,
    login: ""
  });


  useEffect(() => {
    
    if (userInfo.id === 0) {
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

  return (
    <div>
      <Nav>
        <NavItem>
          <UserInfo id={userInfo.id} login={userInfo.login} ></UserInfo>
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
      <Posts>

      </Posts>
  
    </div>
  );
}

export default App;
