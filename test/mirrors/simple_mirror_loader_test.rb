# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'test/unit'
require 'mirah'


java_import 'org.mirah.jvm.mirrors.SimpleMirrorLoader'
java_import 'org.mirah.jvm.mirrors.BaseType'

class ParentLoader < SimpleMirrorLoader
  def initialize
    @callcount = 0
  end

  def findMirror(type)
    @callcount += 1
    BaseType.new(type, 0, nil) if type.descriptor == "V"
  end

  attr_reader :callcount
end

class SimpleMirrorLoaderTest < Test::Unit::TestCase
  java_import 'org.jruby.org.objectweb.asm.Type'

  def setup
    @parent = ParentLoader.new
    @loader = SimpleMirrorLoader.new(@parent)
  end

  def test_no_parent
    assert_nil(SimpleMirrorLoader.new.loadMirror(Type.getType("V")))
    assert_nil(SimpleMirrorLoader.new.loadMirror(Type.getType("I")))
  end

  def test_parent
    type = @loader.loadMirror(Type.getType("V"))
    assert_equal("void", type.name)
    assert_nil(@loader.loadMirror(Type.getType("I")))
  end

  def test_cache
    type = @loader.loadMirror(Type.getType("V"))
    assert_equal("void", type.name)
    type = @loader.loadMirror(Type.getType("V"))
    assert_equal("void", type.name)
    assert_equal(1, @parent.callcount)
  end
end

class PrimitiveLoaderTest < Test::Unit::TestCase
  java_import 'org.mirah.jvm.mirrors.PrimitiveLoader'
  java_import 'org.jruby.org.objectweb.asm.Type'

  def test_primitives
    loader = PrimitiveLoader.new
    %w(V Z B S C I J F D).each do |desc|
      type = Type.getType(desc)
      mirror = loader.loadMirror(type)
      assert_equal(type.getClassName, mirror.name)
      assert_equal(desc, mirror.class_id)
    end
  end

  def test_parent
    parent = ParentLoader.new
    loader = PrimitiveLoader.new(parent)
    mirror = loader.loadMirror(Type.getType("V"))
    assert_equal(1, parent.callcount)
  end
end