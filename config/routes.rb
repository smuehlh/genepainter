Rails.application.routes.draw do

  root to: 'static_pages#home'
  match '/genepainter', to: 'gene_painter#gene_painter', as: 'gene_painter', :via => [:get]
  match '/help', to: 'static_pages#help', as: 'help', :via => [:get]
  match '/download', to: 'static_pages#download', as: 'download', :via => [:get]
  match '/team', to: 'static_pages#team', as: 'team', :via => [:get]
  match '/contact', to: 'static_pages#contact', as: 'contact', :via => [:get]

  match 'upload_sequence', to: 'gene_painter#upload_sequence', as: 'post/upload_sequence', :via => [:post]
  # match 'upload_sequence', to: 'gene_painter#upload_sequence', as: 'get/upload_sequence',:via => [:get]
  match 'upload_gene_structures', to: 'gene_painter#upload_gene_structures', as: 'post/upload_gene_structures', :via => [:post]
  match 'upload_species_mapping', to: 'gene_painter#upload_species_mapping', as: 'post/upload_species_mapping', :via => [:post]
  match 'upload_pdb', to: 'gene_painter#upload_pdb', as: 'post/upload_pdb', :via => [:post]
  match 'update_species_mapping', to: 'gene_painter#update_species_mapping', as: 'post/update_species_mapping', :via => [:post]
  match 'create_alignment_file', to: 'gene_painter#create_alignment_file', as: 'post/create_alignment_file', :via => [:post]
  match 'call_genepainter', to: 'gene_painter#call_genepainter', as: 'post/call_genepainter', :via => [:post]
  match 'build_svg', to: 'gene_painter#build_svg', as: 'post/build_svg', :via => [:post]
  match 'clean_up', to: 'gene_painter#clean_up', as: 'post/clean_up', :via => [:post]
  match 'get_species', to: 'gene_painter#get_species', as: 'post/get_species', :via => [:post]
  match 'download_genestructs', to: 'gene_painter#download_new_genestructs', as: 'get/download_genestructs', :via => [:get]

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
