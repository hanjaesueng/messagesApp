//
//  ChatViewController.swift
//  MessagerPractice
//
//  Created by 김현미 on 2022/02/15.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import CoreLocation
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit


final class ChatViewController: MessagesViewController {

    private var senderPhotoURL : URL?
    private var otherUserPhotoURL : URL?

    public static let dateFormatter : DateFormatter = {
        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        formatter.timeStyle = .long

        formatter.locale = .current
        return formatter
    }()
    
    public var isNewConversation = false
    public let otherUserEmail : String
    private var conversationId : String?
    
    private var messages = [Message]()
    
    private var selfSender : Sender? = {
        guard let email = UserDefaults.standard.string(forKey: "email") else {return nil}
        let safeEmail = DatabaseManager.safeEmail(email: email)
        return Sender(photoURL: "",
               senderId: safeEmail,
               displayName: "Me")
    }()
    
    
    init(with email : String,id:String?) {
        otherUserEmail = email
        conversationId = id
        super.init(nibName: nil, bundle: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .red
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside {[weak self] _ in
            self?.presentInputActionSheet()
        }
        
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
        
    }
    
    private func presentInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Media", message: "What would you like to attach?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionsheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionsheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { [weak self] _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] _ in
            self?.presentLocationInputActionsheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentLocationInputActionsheet(){
        
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Pick Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedLocation in
            guard let self = self else {return}
            guard let messageId = self.createMessageId(),
                  let conversationID = self.conversationId,
                  let name = self.title,
                  let selfSender = self.selfSender else {return}
            
            let longitude = selectedLocation.longitude
            let latitude = selectedLocation.latitude
            print("lon :",longitude,"lat :",latitude)
            
            let locationData = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            let mmessage = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .location(locationData))
            
            DatabaseManager.shared.sendMessage(to: conversationID, otheruserEmail: self.otherUserEmail, name: name, message: mmessage) { success in
                if success {
                    print("sent location message")
                } else {
                    print("failed to send location message")
                }
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    private func presentPhotoInputActionsheet(){
        let actionSheet = UIAlertController(title: "Attach Media", message: "Where would you like to attach a photo from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker,animated:true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker,animated:true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionsheet(){
        let actionSheet = UIAlertController(title: "Attach Video", message: "Where would you like to attach a video from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker,animated:true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker,animated:true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true)

    }
    
    private func listenForMessages(id:String,shouldScrollToBottom:Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id) {[weak self] result in
            switch result {
            case .success(let messages):
                print("succes in getting messages")
                guard !messages.isEmpty else {
                    print("messages are empty")
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                   
                }
                
            case .failure(let error):
                print("failed to get messages : \(error)")
            }
        }

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listenForMessages(id:conversationId, shouldScrollToBottom : true)
        }
    }

}

extension ChatViewController : UIImagePickerControllerDelegate,UINavigationControllerDelegate{
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard
            let messageId = createMessageId(),
            let conversationID = conversationId,
            let name = title,
            let selfSender = selfSender else {
                
                return
            }
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            //Upload image
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let self = self else {return}
                switch result {
                case .success(let urlString):
                    // REady to send Message
                    print("Uploaded Message photo : \(urlString)")
                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else {return}
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let mmessage = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .photo(media))
                    DatabaseManager.shared.sendMessage(to: conversationID, otheruserEmail: self.otherUserEmail, name: name, message: mmessage) { success in
                        if success {
                            print("sent photo message")
                        } else {
                            print("failed to send photo message")
                        }
                    }
                case .failure(let error):
                    print("message photo upload error : \(error)")
                }
            })
        } else if let videoUrl = info[.mediaURL] as? URL {
            let fileName = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            //upload Video
            
            print(fileName)
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in
                guard let self = self else {return}
                switch result {
                case .success(let urlString):
                    // REady to send Message
                    print("Uploaded Message video : \(urlString)")
                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else {return}
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let mmessage = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationID, otheruserEmail: self.otherUserEmail, name: name, message: mmessage) { success in
                        if success {
                            print("sent video message")
                        } else {
                            print("failed to send video message")
                        }
                    }
                case .failure(let error):
                    print("message video upload error : \(error)")
                }
            })
        }
        
        
    }
}


extension ChatViewController : InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty, let selfSender = self.selfSender, let messageID = self.createMessageId() else {
            return
        }
        
        print("sending text:",text)
        let mmessage = Message(sender: selfSender, messageId: messageID, sentDate: Date(), kind: .text(text))
        //Send Message
        if isNewConversation {
            // create convo in database
            
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,name : self.title ?? "User", firstMessage: mmessage) {[weak self] success in
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                    let newConversationId = "conversation_\(mmessage.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                    self?.messageInputBar.inputTextView.text = nil
                } else {
                    print("failed to sent")
                }
            }
        } else {
            guard let conversationId = self.conversationId, let name = self.title else {
                return
            }
            // append to existing conversation data
            DatabaseManager.shared.sendMessage(to: conversationId, otheruserEmail : otherUserEmail,name: name, message: mmessage) {[weak self] success in
                if success {
                    self?.messageInputBar.inputTextView.text = nil
                    print("message sent")
                } else {
                    print("failed to sent")
                }
            }
        }
    }
    
    private func createMessageId() -> String? {
        
        // date, otherUserEmail, senderEmail, randomInt
        
        guard let myEmail = UserDefaults.standard.string(forKey: "email")  else {return nil}
        let currentUserEmail = DatabaseManager.safeEmail(email: myEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(currentUserEmail)+\(dateString)"
        print("created message id:",newIdentifier)
        return newIdentifier
    }
}

extension ChatViewController : MessagesDataSource, MessagesDisplayDelegate, MessagesLayoutDelegate {
    func currentSender() -> SenderType {

        if let sender = selfSender {
            return sender
        }
        fatalError("Self Sender is nil, email should be cached")

    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    

    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {return}
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
        
    }
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // out message that we've sent
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId {
            if let currentUserImageURL = self.senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
            } else {
                //images/safeeamil_profile_picture.png
                //fetch url
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.safeEmail(email: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(for: path, completion: {[weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                })
                
            }
        } else {
            if let otherUserImageURL = self.otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUserImageURL, completed: nil)
            } else {
                //fetch url
                let email = self.otherUserEmail
                let safeEmail = DatabaseManager.safeEmail(email: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(for: path, completion: {[weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                })
            }
        }
    }
    
}


extension ChatViewController : MessageCellDelegate {
  
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            
            return
        }
        
        
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }

    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            
            return
        }
        
        
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {return}
            let vc = PhotoViewerViewController(with: imageUrl)
            
            navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else {return}
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url : videoUrl)
            present(vc,animated : true)
        default:
            break
        }
    }
}

