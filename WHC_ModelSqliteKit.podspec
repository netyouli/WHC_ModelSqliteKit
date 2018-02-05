Pod::Spec.new do |s|

s.name         = "WHC_ModelSqliteKit"
s.version      = "1.3.0"
s.summary      = "专业数据模型存储解决方案(告别直接使用sqlite和coreData)"

s.homepage     = "https://github.com/netyouli/WHC_ModelSqliteKit"

s.license      = "MIT"

s.author             = { "吴海超(WHC)" => "712641411@qq.com" }

s.platform     = :ios
s.platform     = :ios, "6.0"

s.source       = { :git => "https://github.com/netyouli/WHC_ModelSqliteKit.git", :tag => "1.3.0"}

s.source_files  = "WHC_ModelSqliteKit/WHC_ModelSqliteKit/*.{h,m}"
s.default_subspec = 'standard'

# use the built-in library version of sqlite3
s.subspec 'standard' do |ss|
ss.library = 'sqlite3'
ss.source_files = 'WHC_ModelSqliteKit/WHC_ModelSqliteKit/*.{h,m}'
ss.exclude_files = 'WHC_ModelSqliteKit/WHC_ModelSqlite.m'
end

# use SQLCipher and enable -DSQLITE_HAS_CODEC flag
s.subspec 'SQLCipher' do |ss|
ss.dependency 'SQLCipher'
ss.source_files = 'WHC_ModelSqliteKit/WHC_ModelSqliteKit/*.{h,m}'
ss.exclude_files = 'WHC_ModelSqliteKit/WHC_ModelSqlite.m'
ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DHAVE_USLEEP=1' }
end

# s.public_header_files = "Classes/**/*.h"
s.requires_arc = true


end
