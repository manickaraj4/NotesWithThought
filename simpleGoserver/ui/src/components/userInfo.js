import React from "react";
import {Button,Container, Row, Col} from 'react-bootstrap';

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
    this.setState({userId: "", userLogin: ""});
    window.location.replace("/logout")
  }

  componentDidMount(){
  }

  componentDidUpdate(){
  }

  render() {
    let button1, button2;
    if (this.props.sub === "") {
      button1 = <Button variant="success" onClick={this.handleGithubLoginClick}> Login with Github</Button>;
      button2 = <Button variant="success" onClick={this.handleGoogleLoginClick}> Login with Google</Button>;
    } else {
      button1 = <Button variant="dark" onClick={this.handleLogoutClick}> Log Out </Button>;
      button2 = <div></div>
    }

    return (
       <Container className="float-right">
          <Row>
            <Col className="float-right">
              <h4>Welcome {this.props.login}</h4>
            </Col>
          </Row>
          <Row>
            <Col className="float-right">
              {button1}
            </Col>
            <Col className="float-right">
              {button2}
            </Col>
          </Row>
      </Container>
    );
  }
}

export default UserInfo