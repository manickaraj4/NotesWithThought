import React from "react";
import {Button,Container} from 'react-bootstrap';

class UserInfo extends React.Component {
  constructor(props) {
    super(props);
    this.handleGoogleLoginClick = this.handleGoogleLoginClick.bind(this);
    this.handleGithubLoginClick = this.handleGithubLoginClick.bind(this);
    this.handleLogoutClick = this.handleLogoutClick.bind(this);
  }

  handleGithubLoginClick() {
    window.location.replace("/auth/login/github")
    
  }


  handleGoogleLoginClick() {
    window.location.replace("/auth/login/google")
    
  }

  handleLogoutClick() {
    this.setState({userId: 0, userLogin: ""});
    window.location.replace("/logout")
  }

  componentDidMount(){
  }

  componentDidUpdate(){
  }

  render() {
    let button1, button2;
    if (this.props.id === 0) {
      button1 = <Button variant="success" onClick={this.handleGithubLoginClick}> Login with Github</Button>;
      button2 = <Button variant="success" onClick={this.handleGoogleLoginClick}> Login with Google</Button>;
    } else {
      button1 = <Button variant="dark" onClick={this.handleLogoutClick}> Log Out </Button>;
      button2 = <div></div>
    }

    return (
       <Container>
        <h4>Welcome {this.props.login}</h4>
        {button1}{button2}
      </Container>
    );
  }
}

export default UserInfo