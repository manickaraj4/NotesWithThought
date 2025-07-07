import React from "react";
import { Container } from "react-bootstrap";


function BannerDisplay(){

    return(
        <Container className="rounded-lg bg-light">
            <h3> About </h3>
            <p>
                <span>
                A Sample project to build and deploy apps on a self managed Kubernetes cluster on AWS 
                </span>
                <br></br>
                 <span>
            <a
              className="App-link"
              href="https://github.com/manickaraj4/NotesWithThought"
              target="_blank"
              rel="noopener noreferrer"
            >
              Source Code link
            </a>
            </span>
            </p>
        </Container>
    ) 
}

export default BannerDisplay


