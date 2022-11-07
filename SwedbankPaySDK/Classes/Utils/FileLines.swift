//
// Copyright 2020 Swedbank AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

struct FileLines: Sequence, IteratorProtocol {
    internal let file: UnsafeMutablePointer<FILE>
    
    fileprivate init(file: UnsafeMutablePointer<FILE>) {
        self.file = file
    }
    
    func next() -> String? {
        var len: size_t = 0
        guard let cLine = fgetln(file, &len) else {
            return nil
        }
        let data = Data(bytes: cLine, count: len)
        let line = String(data: data, encoding: .utf8)
        return line ?? ""
    }
}

extension UnsafeMutablePointer where Pointee == FILE {
    func getLines() -> FileLines {
        return FileLines(file: self)
    }
}
