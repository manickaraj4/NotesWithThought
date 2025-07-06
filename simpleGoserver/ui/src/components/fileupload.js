import React, { useState } from 'react';
import { Form } from 'react-bootstrap';


const uploaddata = async (formData) => {

    try {
      const request = new Request("/api/fileupload", {
            method: "POST",
            body: formData,
            headers:  {
                'Content-Type': 'multipart/form-data',
                },
            });
      const response = await fetch(request); 
      if (!response.ok) {
        console.log("User is unauthorized Code: ",response.status)
      }
      console.log('File uploaded successfully:', response.data);
      alert('File uploaded successfully!');
    } catch (error) {
      console.error('Error uploading file:', error);
      alert('Error uploading file.');
    }
};

function FileUploadComponent() {
  const [selectedFile, setSelectedFile] = useState(null);

  const handleFileChange = (event) => {
    setSelectedFile(event.target.files[0]);
  };

  const handleUpload = () => {
    if (!selectedFile) {
      alert('Please select a file first!');
      return;
    }
    const formData = new FormData();
    formData.append('file', selectedFile); 
    uploaddata(formData).then((res) => {
        console.log(res)
    });
  }

  return (
    <div>
      <Form.Group controlId="formFileLg" className="mb-3">
        <Form.Label>Select File to Upload</Form.Label>
        <Form.Control type="file" size="sm" onChange={handleFileChange}/>
      </Form.Group>
      <button onClick={handleUpload}>Upload File</button>
    </div>
  );
}

export default FileUploadComponent;