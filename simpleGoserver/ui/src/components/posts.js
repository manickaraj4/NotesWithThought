import React from "react";
import {Container,Table} from 'react-bootstrap';

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

class Posts extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
        posts: []
    };
  }

  componentDidMount() {
    fetchPosts().then((res)=> {
        this.setState({
            posts: res
        })
    });
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
            <h2>Posts</h2>
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
                        </tr>
                    ))}
                </tbody>
            </Table>
        </Container>

    );
  }
}

export default Posts