Pod::Spec.new do |s|

s.name         = "WHC_ModelSqliteKit"
s.version      = "1.1.3"
s.summary      = "专业数据模型存储解决方案(告别直接使用sqlite和coreData)"

s.homepage     = "https://github.com/netyouli/WHC_ModelSqliteKit"

s.license      = "MIT"

s.author             = { "吴海超(WHC)" => "712641411@qq.com" }

s.platform     = :ios
s.platform     = :ios, "6.0"

s.source       = { :git => "https://github.com/netyouli/WHC_ModelSqliteKit.git", :tag => "1.1.3"}

s.source_files  = "WHC_ModelSqliteKit/WHC_ModelSqliteKit/*.{h,m}"
s.libraries      = 'sqlite3.0'

# s.public_header_files = "Classes/**/*.h"
s.requires_arc = true


end
