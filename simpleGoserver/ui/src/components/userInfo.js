import React from "react";

class UserInfo extends React.Component {
  constructor(props) {
    super(props);
    this.handleLoginClick = this.handleLoginClick.bind(this);
    this.handleLogoutClick = this.handleLogoutClick.bind(this);
    this.state = {
      userId: 0,
      userLogin: ""
    };
  }

  handleLoginClick() {
    window.location.replace("/auth/login")
  }

  handleLogoutClick() {
    this.setState({userId: 0, userLogin: ""});
    window.location.replace("/logout")
  }

  render() {
    let button;
    if (this.state.userId === 0) {
      button = <button onClick={this.handleLoginClick}> Login with Github</button>;
    } else {
      button = <button onClick={this.handleLogoutClick}> Log Out </button>;
    }

    return (
      <div>
        <h4>Welcome {this.state.userLogin}</h4>
        {button}
      </div>
    );
  }
}

export default UserInfo