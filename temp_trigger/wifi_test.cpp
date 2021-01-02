#include <ESP8266WiFi.h>

void setup() {
	Serial.begin(9600);
	
	// Log into the wifi network
	WiFi.mode(WIFI_STA);
	WiFi.begin(WIFI_ID, WIFI_PASSWORD);

	while(WiFi.status() != WL_CONNECTED) {
		Serial.print('.');
		delay(500);
	}
}
char* get(char* host, char* uri) {
	WiFiClient client;
	const int port = 80;
	if(!client.connect(host, port)) {
		Serial.println("Connection failed");
		return 1;
	}
	Serial.println("Connection successful!");

	// Assemble and send the HTTP request
	client.printf("GET %s HTTP/1.1\n", uri);
	client.printf("Host: %s\n", host);
	client.println("Accept: */*");
	client.println();

	// Wait for availability. If the status is ever non successful, return a failure
	while(!client.available()) {
		if(client.status() != 4) return 1;
		delay(100);
	}
	
	// Fill a perfectly sized buffer with the response data from the server
	size_t buffer_len = client.available();
	char buffer[buffer_len];
	size_t fill_len = client.readBytes(buffer, buffer_len);

	// The response body is delimited from the header by 2 crlfs (carriage-return/line-feed) i.e. "\r\n\r\n"
	// We determine the starting position of the body by locating this delimiter and adding 4 (because "\r\n\r\n" is 4 chars)
	int body_pos = strstr(buffer, "\r\n\r\n") - buffer + 4;

	// Copy the buffer starting at the body position into a perfectly sized body array
	size_t body_len = buffer_len - body_pos;
	char body[body_len];
	memcpy(body, &buffer[body_pos], body_len);

	Serial.printf("Body: %.*s\n", body_len, body);
	return 0;
}

void loop() {
	int result = get("ifconfig.me", "/");
	Serial.printf("Result: %d\n", result);
	Serial.println("Waiting...");
	delay(20000);
} 
