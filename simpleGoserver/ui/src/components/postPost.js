import React from "react";
import {Button,Container,InputGroup} from 'react-bootstrap';


const postPost = async (post) => {
    try {
        const request = new Request("/posts", {
            method: "POST",
            body: JSON.stringify(post),
            });
        const response = await fetch(request); 
        console.log("waiting for await")
        if (!response.ok) {
        console.log("User is unauthorized Code: ",response.status)
        }
        return 
    } catch (err) {
        console.log(err);
        return 
    } 
}

class PostPost extends React.Component {
  constructor(props) {
    super(props);
    this.handleIdChange = this.handleIdChange.bind(this);
    this.handleBodyChange = this.handleBodyChange.bind(this);
    this.handleSubmitClick = this.handleSubmitClick.bind(this);
    this.state = {
        id: 0,
        body: ""
    };
  }

  handleIdChange(e) {
    this.setState(
        {
            id: e.target.value,
            body: this.state.body
        }
    )
  }

  handleBodyChange(e) {
    this.setState(
        {
            id: this.state.id,
            body: e.target.value
        }
    )
  }

  handleSubmitClick() {
    postPost(this.state).then((res)=>{
        console.log(res)
        this.setState(
            {
                id: 0,
                body: ""
            }
        )
    })
  }

  render() {

    return (

        <Container>
            <InputGroup>
                <InputGroup.Text id="postid" value={this.state.id} onChange={this.handleIdChange} >ID of post</InputGroup.Text>
                <InputGroup.Text id="postbody" value={this.state.body} onChange={this.handleBodyChange} >Body of post</InputGroup.Text>
                <Button onClick={this.handleSubmitClick}>Submit Post</Button>
            </InputGroup>
        </Container>

    );
  }
}

export default PostPost