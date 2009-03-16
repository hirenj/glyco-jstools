require 'lax_residue_names'

module HitCounter
  attr_accessor :hits
  def hits
    @hits ||= 1
  end 
  def seen_structures
    @seen_structs ||= []
    @seen_structs
  end

end

class Monosaccharide
  include HitCounter
end

MATCH_BLOCK = lambda { |residue,other_res,matched_yet|
  residue.equals?(other_res) && ((! matched_yet && ((residue.hits += 1) > -1) && ( residue.seen_structures << other_res.seen_structures[0] != nil )) || true )
}

class GlycodbsController < ApplicationController
  layout 'standard'
  
  # GET /glycodbs
  # GET /glycodbs.xml
  def index
    @glycodbs = Glycodb.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @glycodbs }
    end
  end

  # GET /glycodbs/1
  # GET /glycodbs/1.xml
  def show
    @glycodb = Glycodb.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @glycodb }
    end
  end

  # GET /glycodbs/new
  # GET /glycodbs/new.xml
  def new
    @glycodb = Glycodb.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @glycodb }
    end
  end

  # GET /glycodbs/1/edit
  def edit
    @glycodb = Glycodb.find(params[:id])
  end

  # POST /glycodbs
  # POST /glycodbs.xml
  def create
    @glycodb = Glycodb.new(params[:glycodb])

    respond_to do |format|
      if @glycodb.save
        flash[:notice] = 'Glycodb was successfully created.'
        format.html { redirect_to(@glycodb) }
        format.xml  { render :xml => @glycodb, :status => :created, :location => @glycodb }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @glycodb.errors, :status => :unprocessable_entity }
      end
    end
  end

  def tag
    @glycodb = Glycodb.find(params[:id])
    new_tag = params[:tag]    
    my_tags = (@glycodb.tags || '').split(',').reject { |tag| tag == new_tag }
    my_tags << new_tag
    @glycodb.tags = my_tags.join(',')
    respond_to do |format|
      if @glycodb.save
        format.txt { render :text => @glycodb.tags }
        format.html { render :action => 'show' }
      end
    end
  end

  def tags
    @tags = Glycodb.All_Tags
    @defined_tissues = Enzymeinfo.All_Tissues
    respond_to do |format|
        format.txt { render :text => @tags.join(',') }
        format.html { render :action => 'list_tags' }
    end
  end

  def untag
    @glycodb = Glycodb.find(params[:id])
    new_tag = params[:tag]    
    my_tags = (@glycodb.tags || '').split(',').reject { |tag| tag == new_tag }
    @glycodb.tags = my_tags.join(',')
    respond_to do |format|
      if @glycodb.save
        format.txt { render :text => @glycodb.tags }
        format.html { render :action => 'show' }
      end
    end
  end

  # PUT /glycodbs/1
  # PUT /glycodbs/1.xml
  def update
    @glycodb = Glycodb.find(params[:id])

    respond_to do |format|
      if @glycodb.update_attributes(params[:glycodb])
        flash[:notice] = 'Glycodb was successfully updated.'
        format.html { redirect_to(@glycodb) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @glycodb.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /glycodbs/1
  # DELETE /glycodbs/1.xml
  def destroy
    @glycodb = Glycodb.find(params[:id])
    @glycodb.destroy

    respond_to do |format|
      format.html { redirect_to(glycodbs_url) }
      format.xml  { head :ok }
    end
  end

  def tissue
    @glycodbs = Glycodb.easyfind(:keywords => params[:id], :fieldnames => ['SYSTEM','DIVISION1','DIVISION2','DIVISION3','DIVISION4','SWISS_PROT'])
    @glycodbs.reject! { |glycodb| glycodb.SPECIES != 'HOMO SAPIENS'}
  end

  def proteins
    @glycodbs = Glycodb.find(:all,:conditions => ["species = 'HOMO SAPIENS' and protein_name != ''"],:select => 'SWISS_PROT,PROTEIN_NAME,SPECIES,count(distinct SYSTEM) as system_count,count(*) as record_count',:group => 'protein_name', :order => 'record_count')
    @glycodbs.reject! { |glycodb| glycodb.SPECIES != 'HOMO SAPIENS'}    
  end

  def coverage_for_tag
    @sugars = execute_coverage_for_tag(params[:id])
    @key_sugar = generate_key_sugar()
    render :action => 'coverage', :content_type => Mime::XHTML
  end

  def generate_key_sugar
      key_sug = SugarHelper.CreateMultiSugar('NeuAc(a2-6)[GalNAc(a1-3)]Gal(b1-3)[Fuc(a1-4)]GlcNAc(b1-3)[Fuc(a1-3)[Fuc(a1-2)[NeuAc(a2-3)][Gal(a1-3)]Gal(b1-4)GlcNAc(b1-3)Gal(b1-4)]GlcNAc(b1-6)]Gal(b1-3)[Fuc(a1-6)]GlcNAc',:ic)

      SugarHelper.MakeRenderable(key_sug)        
      
      all_gals = key_sug.residue_composition.select { |r| r.name(:ic) == 'Gal' && r.parent && r.parent.name(:ic) == 'GlcNAc' }
      type_i = all_gals.select { |r| r.paired_residue_position == 3 }
      type_ii = all_gals.select { |r| r.paired_residue_position == 4 }
      all_glcnacs = key_sug.residue_composition.select { |r| r.name(:ic) == 'GlcNAc' && r.parent && r.parent.name(:ic) == 'Gal' }
      type_i_glcnac = all_glcnacs.select { |r| (r.paired_residue_position == 3) && r.parent.paired_residue_position == 3 }
      type_ii_glcnac = all_glcnacs.select { |r| (r.paired_residue_position == 3) && r.parent.paired_residue_position == 4 }
      branching = all_glcnacs.select { |r| r.paired_residue_position == 6 }

      labelled_stuff =
      [ key_sug.find_residue_by_linkage_path([3,6,4,3,4]), # Neuac a2-3 sialylation and Fuc(a1-2)
        key_sug.find_residue_by_linkage_path([3,3,3]), # Neuac a2-6 sialylation
        key_sug.find_residue_by_linkage_path([3,3]).linkage_at_position, # Type 1 chain
        key_sug.find_residue_by_linkage_path([3,6,4]).linkage_at_position, # Type 2 chain
        key_sug.find_residue_by_linkage_path([3,6]).linkage_at_position, # 6-Branching
        key_sug.find_residue_by_linkage_path([3,3]), # Fuc(a1-4)
        key_sug.find_residue_by_linkage_path([3,6]), # Fuc(a1-3)
        key_sug.find_residue_by_linkage_path([]) # Fuc(a1-6)
      ]

      labelled_stuff = labelled_stuff.zip(('a'..'z').to_a[0..(labelled_stuff.size-1)])


      key_sug.callbacks << lambda { |sug_root,renderer|
        renderer.chain_background_width = 20
        renderer.chain_background_padding = 65
        renderer.render_simplified_chains(key_sug,[type_i+type_i_glcnac],'sugar_chain sugar_chain_type_i','#FFEFD8')
        renderer.render_simplified_chains(key_sug,[type_ii+type_ii_glcnac],'sugar_chain sugar_chain_type_ii','#C9F6C6')
        renderer.render_simplified_chains(key_sug,[branching],'sugar_chain sugar_chain_branching','#C5D3EF')
        labelled_stuff.each { |thing,lab|
          next unless thing
          position = :center
          ratio = 0.2
          if thing.kind_of?(Monosaccharide)
            position = :bottom_right
            ratio = 0.5
          end
          thing.callbacks << renderer.callback_make_object_badge(key_sug.overlays[-1],thing,lab,ratio,position,'#222222')
        }
      }
      
      
      key_sug.residue_composition.each { |r|
        def r.hits
          1
        end
      }
      key_sug
  end

  def execute_coverage_for_tag(tags)
    individual_sugars = Glycodb.easyfind(:keywords => tags.split(','), :fieldnames => ['tags']).collect { |entry|
      my_seq = entry.GLYCAN_ST.gsub(/\+.*/,'').gsub(/\(\?/,'(u')
      my_sug = nil
      begin
        my_sug = SugarHelper.CreateMultiSugar(my_seq,:ic).get_unique_sugar        
        my_sug.residue_composition.each { |res|
          res.seen_structures << entry.id
        }
      rescue Exception => e
      end
      my_sug
    }.compact
    sugar_sets = 
      [ individual_sugars.reject { |sug| sug.root.name(:ic) != 'GlcNAc'},
        individual_sugars.reject { |sug| sug.root.name(:ic) != 'GalNAc'},
        individual_sugars.reject { |sug| sug.root.name(:ic) != 'Gal'},
        individual_sugars.reject { |sug| sug.root.name(:ic) != 'Glc'}
      ].compact
    return sugar_sets.collect { |sugar_set|
      sugar = sugar_set.shift
      def sugar.add_structure_count
        @struct_count = (@struct_count || 0) + 1
      end
      def sugar.structure_count
        @struct_count
      end
      
      def sugar.branch_points_count=(new_bc)
        @branch_points = new_bc
      end
      
      def sugar.branch_points_count
        @branch_points
      end
      
      def sugar.branch_point_totals
        @branch_point_totals
      end
      
      def sugar.branch_point_totals=(totals)
        @branch_point_totals = totals
      end
      
      if sugar == nil
        next
      end
            
      # Branch point comparison
      # For each branch point for the new sugar collect
      #    get the unambiguous path to root for the branch point
      #    find the analgous residue in the target sugar
      # end
      # Update the counter hash for each branch point
      # counts[a_branch_point][co-occuring_branch_point] += 1
      # counts[a_branch_point][self] += 1
      #
      # Profit!
      
      branch_points_totals = []
      
      sugar_set.each { |sug|
        branch_points = sug.branch_points
        sugar.union!(sug,&MATCH_BLOCK)
        branch_points = branch_points.collect { |r| sugar.find_residue_by_unambiguous_path(sug.get_unambiguous_path_to_root(r).reverse) }
        branch_points_totals << branch_points
        sugar.add_structure_count
      }

      branch_totals_by_point = {}
      branch_points_totals.each { |branching_rec|
        branching_rec.each { |point|
          branch_totals_by_point[point] ||= {}
          branching_rec.each { |other_point|
            branch_totals_by_point[point][other_point] ||= 0
            branch_totals_by_point[point][other_point] += 1            
          }
        }
      }

      sugar.branch_point_totals = branch_totals_by_point

      SugarHelper.MakeRenderable(sugar)        
      
    
      coverage_finder = EnzymeCoverageController.new()
      coverage_finder.sugar = sugar
      sugar.root.anomer = 'u'
      
      coverage_finder.execute_pathways_and_markup

      sugar.residue_composition.each { |r|
        if ! r.is_valid? && r.parent && r.parent.is_valid?
          r.parent.remove_child(r)
        end
      }
      
      all_gals = sugar.residue_composition.select { |r| r.name(:ic) == 'Gal' && r.parent && r.parent.name(:ic) == 'GlcNAc' }
      type_i = all_gals.select { |r| r.paired_residue_position == 3 }
      type_ii = all_gals.select { |r| r.paired_residue_position == 4 }
      all_glcnacs = sugar.residue_composition.select { |r| r.name(:ic) == 'GlcNAc' && r.parent && r.parent.name(:ic) == 'Gal' }
      type_i_glcnac = all_glcnacs.select { |r| (r.paired_residue_position == 3) && r.parent.paired_residue_position == 3 }
      type_ii_glcnac = all_glcnacs.select { |r| (r.paired_residue_position == 3) && r.parent.paired_residue_position == 4 }
      branching = all_glcnacs.select { |r| r.paired_residue_position == 6 }
      
      sugar.callbacks << lambda { |sug_root,renderer|
        renderer.chain_background_width = 20
        renderer.chain_background_padding = 65
#        renderer.render_valid_decorations(sugar,valid_residues.uniq)
#        renderer.render_invalid_decorations(sugar,invalid_residues.uniq)
        renderer.render_simplified_chains(sugar,[type_i+type_i_glcnac],'sugar_chain sugar_chain_type_i','#FFEFD8')
        renderer.render_simplified_chains(sugar,[type_ii+type_ii_glcnac],'sugar_chain sugar_chain_type_ii','#C9F6C6')
        renderer.render_simplified_chains(sugar,[branching],'sugar_chain sugar_chain_branching','#C5D3EF')
      }
      
      sugar_residues = sugar.residue_composition
      branch_totals_by_point.keys.each { |bp|
        unless sugar_residues.include? bp
            branch_totals_by_point.delete(bp)
        end
      }
      all_ids = branch_totals_by_point.keys.collect { |bp|
        bp.seen_structures
      }.flatten.sort

      zero_count = sugar.root.hits
      sizes = {}
      all_id_sizes = all_ids.group_by { |i| i }.collect { |arr| arr[1].size }.group_by { |i| i }.each { |b_num,scount|
        sizes[b_num] = scount.size
        zero_count -= scount.size
      }
      sizes[0] = zero_count
      sugar.branch_points_count = sizes

      labels = ('V'..'Z').to_a
      
      branch_totals_by_point.keys.each { |bp|
        branch_label_text = labels.shift
        def bp.branch_label
          @branch_label
        end
       def bp.branch_label=(new_label)
         @branch_label = new_label
       end
       bp.branch_label = branch_label_text

        sugar.callbacks << lambda { |sug_root,renderer|
          renderer.render_text_residue_label(sugar,bp,branch_label_text)
        }
      }

      targets = Element.new('svg:g')
      targets.add_attributes({'class' => 'hits_overlay', 'display' => 'none'})
      sugar.overlays << targets
      sugar.residue_composition.each { |residue|
        residue.hits += 1
        residue.callbacks.push( lambda { |element|
          xcenter = -1*(residue.centre[:x]) 
          ycenter = -1*(residue.centre[:y])
          label = Element.new('svg:text')
          label.add_attributes({'x' => xcenter, 'y' => ycenter, 'text-anchor' => 'middle', 'style' => 'dominant-baseline: middle;','font-size' => '40px' })
          label.text = residue.hits
          label_back = Element.new('svg:circle')
          label_back.add_attributes({'cx' => xcenter, 'cy' => ycenter, 'r' => '40px', 'fill' => '#ffffff', 'stroke-width' => '2px', 'stroke' => '#0000ff'})

          targets.add_element(label_back)
          targets.add_element(label)
          
        })
      }

      gene_tissue = (tags.split(',').collect { |tag| tag.gsub!(/anat\:/,'') }.compact.first || 'nil').humanize
      coverage_finder.markup_linkages(coverage_finder.execute_genecoverage(gene_tissue))
      sugar
    }.compact
  end
end
