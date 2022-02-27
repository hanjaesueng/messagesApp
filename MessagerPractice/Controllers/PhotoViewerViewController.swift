//
//  PhotoViewerViewController.swift
//  MessagerPractice
//
//  Created by jaeseung han on 2022/02/06.
//

import UIKit

import SDWebImage

final class PhotoViewerViewController: UIViewController {

    private let url : URL
    
    init(with url : URL){
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Photo"
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(imageView)
        imageView.sd_setImage(with: url, completed: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.frame = view.bounds
    }

}
