import logo from './logo.svg';
import './App.css';
import UserInfo from './components/userInfo';
import { useState, useEffect } from 'react';

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
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const result = await response.json();
        setUserInfo(result)
      } catch (err) {
        console.log(err);
      } 
    };
    fetchUser();
  }, [userInfo]);

  return (
    <div className="App">
      <UserInfo props={userInfo}></UserInfo>

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
