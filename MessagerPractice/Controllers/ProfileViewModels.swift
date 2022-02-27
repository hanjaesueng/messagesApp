//
//  ProfileViewModels.swift
//  MessagerPractice
//
//  Created by 김현미 on 2022/02/27.
//

import Foundation

enum ProfileViewModelType {
    case info, logout
}
struct ProfileViewModel {
    let viewModelType : ProfileViewModelType
    let title : String
    let handler : (() -> ())?
    
}
