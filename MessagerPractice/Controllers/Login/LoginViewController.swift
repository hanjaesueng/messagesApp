//
//  LoginViewController.swift
//  MessagerPractice
//
//  Created by jaeseung han on 2022/02/06.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import Firebase
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let imageView : UIImageView = {
        let imageV = UIImageView()
        imageV.image = UIImage(named: "messenger")
        imageV.contentMode = .scaleAspectFit
        return imageV
    }()
    
    private let scrollView : UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    
    private let passwordField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton : UIButton = {
        let btn = UIButton()
        btn.setTitle("Log In", for: .normal)
        btn.backgroundColor = .link
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.layer.masksToBounds = true
        btn.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return btn
    }()
    
    private let fbLoginButton : FBLoginButton = {
        let btn = FBLoginButton()
        btn.layer.cornerRadius = 12
        btn.permissions = ["public_profile", "email"]
        btn.layer.masksToBounds = true
        return btn
    }()
    
    private let googleLoginButton = GIDSignInButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        title = "Log in"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(didTapRegister))
        
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        googleLoginButton.addTarget(self, action: #selector(googleLoginButtonTapped), for: .touchUpInside)
        emailField.delegate = self
        passwordField.delegate = self
        
        // add SubViews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(fbLoginButton)
        scrollView.addSubview(googleLoginButton)
        fbLoginButton.delegate = self

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: (scrollView.width-size)/2, y: 20, width: size, height: size)
        emailField.frame = CGRect(x: 30, y: imageView.bottom + 10, width: scrollView.width - 60, height: 52)
        passwordField.frame = CGRect(x: 30, y: emailField.bottom + 10, width: scrollView.width - 60, height: 52)
        loginButton.frame = CGRect(x: 30, y: passwordField.bottom + 10, width: scrollView.width - 60, height: 52)
        fbLoginButton.frame = CGRect(x: 30, y: loginButton.bottom + 10, width: scrollView.width - 60, height: 52)
        googleLoginButton.frame = CGRect(x: 30, y: fbLoginButton.bottom + 10, width: scrollView.width - 60, height: 52)
    }
    
    @objc private func googleLoginButtonTapped() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(with: config, presenting: self) { [weak self] user, error in
            guard let self = self else {return}
            if let error = error {
                // ...
                print(error)
                return
            }
            
            guard let authentication = user?.authentication,let idToken = authentication.idToken else {
                print("Missing auth object off of google user")
                return
            }
            let email = user?.profile?.email
            let firstname = user?.profile?.familyName ?? "family name"
            let lastName = user?.profile?.givenName ?? "given name"
            if let email = email {

                
                UserDefaults.standard.set(email,forKey: "email")
                UserDefaults.standard.set("\(firstname) \(lastName)",forKey: "name")
                
                DatabaseManager.shared.userExists(with: email) { exists in
                    if !exists {
                        // insert to dataase
                        let chatUser = ChatAppUser(firstName: firstname ?? "", lastName: lastName ?? "", emailAddress: email)
                        DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                            if success {
                                
                                if let imageHade = user?.profile?.hasImage, imageHade {
                                    guard let url = user?.profile?.imageURL(withDimension: 200) else {
                                        return
                                    }
                                    
                                    URLSession.shared.dataTask(with: url) { data, _, _ in
                                        guard let data = data else {
                                            return
                                        }
                                        let fileName = chatUser.profilePictureFileName
                                        StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                                            switch result {
                                            case .success(let downloadUrl):
                                                UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                                print(downloadUrl)
                                            case .failure(let error):
                                                print("Storage manager error : \(error)")
                                            }
                                        }
                                    }.resume()
                                    
                                }
                                
                                
                            } else {
                                
                            }
                        })
                    }
                }
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: authentication.accessToken)
            self.spinner.show(in: self.view)
            FirebaseAuth.Auth.auth().signIn(with: credential) { authResult, error in
                DispatchQueue.main.async {
                    self.spinner.dismiss()
                }
                guard authResult != nil, error == nil else {
                    print("failed to login with google credential")
                    return
                }
                
                self.navigationController?.dismiss(animated: true, completion: nil)
                print("Successfully signed in with Google cred.")
                
            }
            
        }
    }
    @objc private func loginButtonTapped() {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        guard let email = emailField.text, let password = passwordField.text, !email.isEmpty, !password.isEmpty, password.count >= 6 else {
            alerUserLoingError()
            return
        }
        
        spinner.show(in: view)
        
        //Firebase Login
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) {[weak self] result, error in
            guard let self = self else {return}
            DispatchQueue.main.async {
                self.spinner.dismiss()
            }
            
            guard error == nil , let result = result else {
                let alert = UIAlertController(title: "login fail", message: "check your email or password", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                self.present(alert,animated: true)
                return
            }

            let user = result.user
            
            let safeEmail = DatabaseManager.safeEmail(email: email)
            DatabaseManager.shared.getDataFor(path: safeEmail) { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String : Any],
                          let firstName = userData["first_name"],
                          let lastName = userData["last_name"] else {return}
                    UserDefaults.standard.set("\(firstName) \(lastName)",forKey: "name")
                case .failure(let error):
                    print("Failed to read data with error \(error)")
                }
            }
            
            
            UserDefaults.standard.set(email,forKey: "email")
            
            print("Logged In User : \(user)")

            // 로그인 성공
            self.navigationController?.dismiss(animated: true, completion: nil)
            
        }
    }
    
    func alerUserLoingError(){
        let alert = UIAlertController(title: "Woops", message: "Please enter all information to login", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert,animated: true)
    }
    
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension LoginViewController : UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
}

extension LoginViewController : LoginButtonDelegate {
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        // no operation
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("User failed to log in with facebook")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me", parameters: ["fields":"email, first_name, last_name, picture.type(large)"], tokenString: token, version: nil,httpMethod: .get)
        
        facebookRequest.start {[weak self] _, result, error in
            guard let self = self else {return}
            guard let result = result as? [String:Any], error == nil else {
                print("Failed to make facebook graph request")
                return
            }
            
            print(result)

            guard let firstName  = result["first_name"] as? String,
                  let lastName  = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String:Any],
                  let data = picture["data"] as? [String:Any],
                  let pictureUrl = data["url"] as? String else {
                      print("Failed to get email and name from fb result")
                      return
                  }
            UserDefaults.standard.set("\(firstName) \(lastName)",forKey: "name")
            UserDefaults.standard.set(email,forKey: "email")


            
            DatabaseManager.shared.userExists(with: email) { exists in
                if !exists {
                    let chatUser = ChatAppUser(firstName: String(firstName), lastName: lastName, emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                        if success {
                            guard let url = URL(string: pictureUrl) else {return}
                            
                            print("Downloading data from facebook image")
                            URLSession.shared.dataTask(with: url) { data, _, _ in
                                guard let data = data else {
                                    print("failed get data from FB")
                                    return
                                }
                                
                                print("got data from FB, uploading...")
                                
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                                    switch result {
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                        print(downloadUrl)
                                    case .failure(let error):
                                        print("Storage manager error : \(error)")
                                    }
                                }
                            }.resume()
                            
                        } else {
                            
                        }
                    })
                } else {
                    print("already exists")
                }
            }
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            self.spinner.show(in: self.view)
            FirebaseAuth.Auth.auth().signIn(with: credential) {[weak self] authResult, error in
                guard let self = self else {return}
                DispatchQueue.main.async {
                    self.spinner.dismiss()
                }
                guard let _ = authResult , error == nil else {
                    if let error = error {
                        print("Facebook credential login failed, MFA may be needed - \(error)")
                    }
                    
                    return
                }
                
                print("Successfully login in facebook")
                self.navigationController?.dismiss(animated: true, completion: nil)
            }
        }
        
        
    }
    
    
}
