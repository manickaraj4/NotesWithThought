import React from "react";
import {Button,Container} from 'react-bootstrap';

class UserInfo extends React.Component {
  constructor(props) {
    super(props);
    this.handleLoginClick = this.handleLoginClick.bind(this);
    this.handleLogoutClick = this.handleLogoutClick.bind(this);
    this.state = {
      userId: props.id,
      userLogin: props.login
    };
  }

  handleLoginClick() {
    window.location.replace("/auth/login")
    
  }

  handleLogoutClick() {
    this.setState({userId: 0, userLogin: ""});
    window.location.replace("/logout")
  }

  componentDidMount(){
    console.log("Initial moun of the user info component")
    console.log(this.state);
  }

  componentDidUpdate(){
    console.log("Updated the user info component")
    console.log(this.state);
  }

  render() {
    let button;
    if (this.state.userId === 0) {
      button = <Button onClick={this.handleLoginClick}> Login with Github</Button>;
    } else {
      button = <Button onClick={this.handleLogoutClick}> Log Out </Button>;
    }

    return (
       <Container>
        <h4>Welcome {this.state.userLogin}</h4>
        {button}
      </Container>
    );
  }
}

export default UserInfo