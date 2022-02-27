//
//  ViewController.swift
//  MessagerPractice
//
//  Created by jaeseung han on 2022/02/06.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation {
    let id : String
    let name : String
    let otherUserEmail : String
    let latestMessage : LatestMessage
}

struct LatestMessage {
    let date : String
    let text : String
    let isRead : Bool
}

class ConversationViewController: UIViewController {

    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    private var loginObserver : NSObjectProtocol?
    
    private let tableView : UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return table
    }()
    
    private let noConversationsLabel : UILabel = {
        let label = UILabel()
        label.text = "No Conversations!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButton))
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setupTableView()
        startListeningForConversations()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else {return}
            self.startListeningForConversations()
        }
    }
    
    private func startListeningForConversations() {
        guard let email = UserDefaults.standard.string(forKey: "email") else {return}
        print("starting conversation fetch...")
        
        if let loginObserver = loginObserver {
            NotificationCenter.default.removeObserver(loginObserver)
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail) {[weak self] result in
            switch result {
            case .success(let conversations):
                print("successfully got conversation models")
                print(conversations)
                guard !conversations.isEmpty else {
                    self?.noConversationsLabel.isHidden = false
                    return
                }
                self?.conversations = conversations
                self?.noConversationsLabel.isHidden = true
                self?.tableView.isHidden = false
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                print("Failed to get convos : \(error)")
            }
        }
    }

    @objc private func didTapComposeButton(){
        let vc = NewConversationViewController()
        vc.completion = {[weak self] result in
            guard let self = self else {return}
            
            
            let currentConversations = self.conversations
            
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager.safeEmail(email: result.email)
            }) {
                let vc = ChatViewController(with: targetConversation.otherUserEmail ,id:targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                self.createNewConversation(result: result)
            }
            
        }
        
        
        
        
        
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC,animated: true)
    }
    
    private func createNewConversation(result : SearchResult) {
        let name = result.name
        let safeEmail = DatabaseManager.safeEmail(email: result.email)
        // check in database if conversation with these two users exists
        // if it does, reuse conversation id
        // otherwise use existing code
        
        DatabaseManager.shared.conversationExists(with: safeEmail) { [weak self] result in
            guard let self = self else {return}
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: safeEmail,id:conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: safeEmail,id:nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
        
    
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationsLabel.frame = CGRect(x: 10, y: (view.height - 100)/2, width: view.width - 20, height: 100)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
       
    }
    private func validateAuth(){
        
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav,animated: true)
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
   
}

extension ConversationViewController : UITableViewDelegate,UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier,for: indexPath) as! ConversationTableViewCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversation(model)
    }
    
    func openConversation(_ model : Conversation){
        let vc = ChatViewController(with: model.otherUserEmail,id : model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            //begin delete
            let conversationid = conversations[indexPath.row].id
            tableView.beginUpdates()
            
            DatabaseManager.shared.deleteConversation(conversationId: conversationid) {[weak self] success in
                if success {
                    self?.conversations.remove(at: indexPath.row)
                    
                    tableView.deleteRows(at: [indexPath], with: .left)
                }
            }
            
            
            
            tableView.endUpdates()
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
}
