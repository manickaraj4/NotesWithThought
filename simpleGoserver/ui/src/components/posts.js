import React from "react";
import {Button,Container,Table} from 'react-bootstrap';

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
    this.state = {
       posts: []
       /* posts: [
        {
            id: 1,
            body: "hello"
        }
       ] */
    };
  }

  handleDeletePost(id) {
    deletePost(id).then((res)=>{
        console.log(res);
        fetchPosts().then((res)=> {
            this.setState({
                posts: res
            })
        });
        this.render()
    })
  }

  componentDidMount() {
    if(this.props.reload){
        fetchPosts().then((res)=> {
            this.setState({
                posts: res
            })
        });
     }
  }

  componentDidUpdate() {

    if(this.props.reload){
        fetchPosts().then((res)=> {
            this.setState({
                posts: res
            })
        });
     }
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

        <Container>
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

    );
  }
}

export default Posts