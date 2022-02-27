//
//  ProfileViewController.swift
//  MessagerPractice
//
//  Created by jaeseung han on 2022/02/06.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage



final class ProfileViewController: UIViewController {

    @IBOutlet var tableView : UITableView!
    
    var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        data.append(ProfileViewModel(viewModelType: .info, title: "Name : \(UserDefaults.standard.string(forKey: "name") ?? "No name")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .info, title: "email : \(UserDefaults.standard.string(forKey: "email") ?? "No email")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: {[weak self] in
            guard let self = self else {return}
            let alert = UIAlertController(title: "Logout action",
                                          message: "",
                                          preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Log Out",
                                          style: .destructive,
                                          handler: {[weak self] _ in
                guard let self = self else {return}
                
                UserDefaults.standard.setValue(nil, forKey: "email")
                UserDefaults.standard.setValue(nil, forKey: "name")
                if self.isFacebookLoggedIn() {
                    LoginManager.init().logOut()
                }
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav,animated: true)
                }catch{
                    print("failed to log out")
                }
                
            }))
            alert.addAction(UIAlertAction(title: "cancel",
                                          style: .cancel,
                                          handler: nil))
            self.present(alert, animated: true)
        }))
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.string(forKey: "email") else {
            
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let filename = safeEmail + "_profile_picture.png"
        
        let path = "images/"+filename
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.width, height: 300))
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: (view.width - 150) / 2, y: 75, width: 150, height: 150))
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2 
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path) { result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("Failed to get download url:",error)
            }
        }
        return headerView
    }
    


}

extension ProfileViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setUP(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        data[indexPath.row].handler?()
        
    }
    
    func isFacebookLoggedIn() -> Bool {
        let isTokenExist = AccessToken.current?.tokenString != nil
        let isTokenValid = !(AccessToken.current?.isExpired ?? true)
        return isTokenExist && isTokenValid
    }
    
}

class ProfileTableViewCell : UITableViewCell {
    static let identifier = "ProfileTableViewCell"
    public func setUP(with viewModel : ProfileViewModel){
        textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            textLabel?.textAlignment = .left
            selectionStyle = .none
        case .logout:
            textLabel?.textColor = .red
            textLabel?.textAlignment = .center
        }
    }
}
