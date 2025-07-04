import logo from './logo.svg';
import './App.css';
import UserInfo from './components/userInfo';
import { useState, useEffect } from 'react';
import { Button, Navbar, Nav, NavItem } from 'react-bootstrap';

function App() {

  const [userInfo, setUserInfo] = useState({
    "id" : 0,
    "login": ""
  });

  useEffect(() => {
    console.log("Inside useEffect")
    const fetchUser = async () => {
      try {
        const response = await fetch('/userinfo'); 
        console.log("waiting for await")
        if (!response.ok) {
          console.log("User is unauthorized Code: ",response.status)
        }
        const result = await response.json();
        setUserInfo(result)
      } catch (err) {
        console.log(err);
      } 
    };
    if (userInfo === 0) {
      fetchUser();
    }
  }, []);

  return (
    <div className="App">
      <Nav>
        <NavItem>
        <UserInfo props={userInfo}></UserInfo>
        </NavItem>
      </Nav>
    
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
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
      </header>
    </div>
  );
}

export default App;
