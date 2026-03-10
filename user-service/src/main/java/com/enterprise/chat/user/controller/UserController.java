package com.enterprise.chat.user.controller;

import com.enterprise.chat.user.dto.RegistrationRequest;
import com.enterprise.chat.user.model.User;
import com.enterprise.chat.user.repository.UserRepository;
import jakarta.ws.rs.core.Response;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.keycloak.admin.client.Keycloak;
import org.keycloak.admin.client.resource.RealmResource;
import org.keycloak.admin.client.resource.UsersResource;
import org.keycloak.representations.idm.CredentialRepresentation;
import org.keycloak.representations.idm.UserRepresentation;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Collections;
import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Slf4j
public class UserController {

    private final UserRepository userRepository;
    private final Keycloak keycloak;

    @PostMapping("/register")
    public ResponseEntity<?> registerUser(@RequestBody RegistrationRequest request) {
        log.info("Received registration request for user: {}", request.getUsername());
        
        if (userRepository.existsById(request.getUsername())) {
            return ResponseEntity.badRequest().body("Username already exists in local DB.");
        }

        try {
            RealmResource realmResource = keycloak.realm("chat-realm");
            UsersResource usersResource = realmResource.users();

            // 1. Prepare Keycloak User Representation
            UserRepresentation kcUser = new UserRepresentation();
            kcUser.setUsername(request.getUsername());
            kcUser.setEmail(request.getEmail() != null && !request.getEmail().isEmpty() ? request.getEmail() : request.getUsername() + "@enterprise.com");
            kcUser.setFirstName(request.getFirstName());
            kcUser.setLastName(request.getLastName());
            kcUser.setEnabled(true);

            // 2. Prepare Password Credential
            CredentialRepresentation credential = new CredentialRepresentation();
            credential.setTemporary(false);
            credential.setType(CredentialRepresentation.PASSWORD);
            credential.setValue(request.getPassword());
            kcUser.setCredentials(Collections.singletonList(credential));

            // 3. Create User in Keycloak
            Response response = usersResource.create(kcUser);

            if (response.getStatus() == 409 || response.getStatus() == 400) {
                log.warn("Keycloak rejected user creation. Invalid input, email format, or user exists. Status: {}", response.getStatus());
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Kullanıcı adı/e-posta zaten kullanımda veya geçersiz e-posta formatı/zayıf şifre girdiniz.");
            } else if (response.getStatus() != 201) {
                log.error("Failed to create user in Keycloak. Status: {}. Info: {}", response.getStatus(), response.getStatusInfo());
                return ResponseEntity.status(response.getStatus()).body("Keycloak user creation failed.");
            }

            // Extract the Keycloak generated UUID if needed, here we use username as primary ID for simplicity
            String userId = response.getLocation().getPath().replaceAll(".*/([^/]+)$", "$1");

            // 4. Create internal Relational User Profile
            User localUser = User.builder()
                    .id(request.getUsername())
                    .username(request.getUsername())
                    .email(kcUser.getEmail())
                    .firstName(request.getFirstName())
                    .lastName(request.getLastName())
                    .online(true)
                    .build();

            User savedLocalUser = userRepository.save(localUser);
            log.info("User created in Keycloak with ID: {}", userId); // Use userId to fix unused lint
            return ResponseEntity.status(HttpStatus.CREATED).body(savedLocalUser);

        } catch (Exception e) {
            log.error("Error during registration process", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Registration failed due to server error.");
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<User> getUser(@PathVariable String id) {
        return userRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<User> updateStatus(@PathVariable String id, @RequestParam String statusMessage) {
        return userRepository.findById(id).map(user -> {
            user.setStatusMessage(statusMessage);
            return ResponseEntity.ok(userRepository.save(user));
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{username}/avatar")
    public ResponseEntity<String> updateAvatar(@PathVariable String username, @RequestParam String url) {
        return userRepository.findById(username).map(user -> {
            user.setAvatarUrl(url);
            userRepository.save(user);
            return ResponseEntity.ok("Avatar updated");
        }).orElse(ResponseEntity.notFound().build());
    }
}
