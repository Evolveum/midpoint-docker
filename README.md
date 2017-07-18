MidPoint is open identity & organization management and governance platform which uses Identity Connector Framework (ConnId) and leverages Spring framework. It is a Java application running in Java Web container. This image is based on Tomcat version 8.0.44 image which uses JRE8 and deploys latest MidPoint version 3.6.

Image:
Download: 	docker pull evolveum/midpoint
Run: 		docker run -d -p 8080:8080 --name midpoint evolveum/midpoint:latest
Admin: 		docker exec -it midpoint bash
Tags: 		latest: MidPoint v3.6

MidPoint:
Url: 		http://localhost:8080/midpoint
Credentials: 
		username: administrator
		password: 5ecr3t
Home: 		/var/opt/midpoint/
