import React from "react";
import {Button,Container,Table,InputGroup,Form} from 'react-bootstrap';

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

const fetchPosts = async () => {
    try {
        const response = await fetch('/posts'); 
        console.log("waiting for await")
        if (!response.ok) {
        console.log("User is unauthorized Code: ",response.status)
        }
        return await response.json();
    } catch (err) {
        console.log(err);
        return []
    } 
};

const deletePost = async(id) => {
    try {
        const request = new Request(`/posts/${id}`, {
            method: "DELETE"
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

class Posts extends React.Component {
  constructor(props) {
    super(props);
    this.handleBodyChange = this.handleBodyChange.bind(this);
    this.handleSubmitClick = this.handleSubmitClick.bind(this);
    this.handleDeletePost = this.handleDeletePost.bind(this);
    this.state = {
       posts: [],
       currentPostBody: ""
       /* posts: [
        {
            id: 1,
            body: "hello"
        }
       ] */
    };
  }

  handleBodyChange(e) {
    this.setState(
        {
            posts: this.state.posts,
            currentPostBody: e.target.value
        }
    )
  }

  handleSubmitClick() {
    postPost({id:0,body:this.state.currentPostBody}).then((res)=>{
        console.log(res)
        fetchPosts().then((res)=> {
            this.setState({
                posts: res,
                currentPostBody: ""
            })
        });
        this.render()
        
    })
  }
  
  handleDeletePost(id) {
    deletePost(id).then((res)=>{
        console.log(res);
        fetchPosts().then((res)=> {
            this.setState({
                posts: res,
                currentPostBody: ""
            })
        });
        this.render()
    })
  }

  componentDidMount() {
        fetchPosts().then((res)=> {
            this.setState({
                posts: res
            })
        });
  }

  componentDidUpdate() {

/*     if(this.props.reload){
        fetchPosts().then((res)=> {
            this.setState({
                posts: res
            })
        });
     } */
  }

/*   componentDidUpdate() {
    if(this.state.refresh) {
        fetchPosts().then((res)=> {
            this.setState({
                posts: res,
                refresh: false
            })
    });
    }
    this.setState({
        posts: this.state.posts,
        refresh: false
    })
  } */

  render() {

    return (
        <div>
        <Container>
            <h2>Here to take a note for yourself</h2>
            <InputGroup>
                <InputGroup.Text id="postbody" >Type Something</InputGroup.Text>
                <Form.Control value={this.state.currentPostBody} onChange={this.handleBodyChange} />
            </InputGroup>
            <Button onClick={this.handleSubmitClick}>Submit Post</Button>
        </Container>

        <Container>
            <h4>Reload: {this.props.reload}</h4>
            <h2>Your Notes</h2>
            <Table>
                <thead>
                    <tr>
                    <th>ID</th>
                    <th>Message</th>
                    </tr>
                </thead>
                <tbody>
                    {this.state.posts.map(item => (
                        <tr key={item.id}>
                            <td>{item.id}</td>
                            <td>{item.body}</td>
                            <td><Button variant="outline-danger" onClick={()=>{this.handleDeletePost(item.id)}}>Delete</Button></td>
                        </tr>
                    ))}
                </tbody>
            </Table>
        </Container>
        </div>
    );
  }
}

export default Posts