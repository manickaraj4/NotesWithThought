import logo from './logo.svg';
import './App.css';
import UserInfo from './components/userInfo';
import PostPost from './components/postPost';
import Posts from './components/posts';
import { useState, useEffect } from 'react';
import { Nav, NavItem, Navbar } from 'react-bootstrap';

const fetchUser = async () => {
  try {
    const response = await fetch('/userinfo'); 
    console.log("waiting for await")
    if (!response.ok) {
      console.log("User is unauthorized Code: ",response.status)
    }
    return await response.json();
  } catch (err) {
    console.log(err);
    return {
      id : 0,
      login: ""
    }
  } 
};

function App() {

  const [userInfo, setUserInfo] = useState({
    "id" : 0,
    "login": ""
  });

  useEffect(() => {
    console.log("Inside useEffect")
    if (userInfo === 0) {
      setUserInfo(fetchUser());
    }
  }, []);

  return (
    <div className="App">
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
      <Nav>
        <NavItem>
        <UserInfo props={userInfo}></UserInfo>
        </NavItem>
      </Nav>
      <PostPost>

      </PostPost>
      <Posts>

      </Posts>
  
    </div>
  );
}

export default App;
