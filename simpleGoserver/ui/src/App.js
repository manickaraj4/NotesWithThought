import logo from './logo.svg';
import './App.css';
import UserInfo from './components/userInfo';
import PostPost from './components/postPost';
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
  const [loadPosts, setLoadPosts] = useState(false)

  const reloadPosts = () => {
    setLoadPosts(true)
    setLoadPosts(false)
  }

  useEffect(() => {
    
    if (userInfo.id === 0) {
      console.log("Inside useEffect")
      fetchUser().then((res)=> {
        console.log("Inside then")
        setUserInfo(res);
        setLoadPosts(true)
      }).catch((err)=> {
        console.log(err)
      })
      console.log("After fetchUser")
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
          <UserInfo id={userInfo.id} login={userInfo.login} ></UserInfo>
        </NavItem>
      </Nav>
      <PostPost updateFromChild={reloadPosts} >

      </PostPost>
      <Posts reload={loadPosts} updateFromChild={reloadPosts}>

      </Posts>
  
    </div>
  );
}

export default App;
