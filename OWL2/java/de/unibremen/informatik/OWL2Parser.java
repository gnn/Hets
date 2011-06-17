import org.semanticweb.owlapi.apibinding.OWLManager;
import org.semanticweb.owlapi.model.OWLException;
import org.semanticweb.owlapi.model.OWLOntology;
import org.semanticweb.owlapi.model.OWLOntologyManager;
import org.semanticweb.owlapi.model.IRI;
import uk.ac.manchester.cs.owl.owlapi.mansyntaxrenderer.ManchesterOWLSyntaxRenderer;
import uk.ac.manchester.cs.owl.owlapi.mansyntaxrenderer.ManchesterOWLSyntaxObjectRenderer;

import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.OutputStreamWriter;
import java.io.File;
import java.io.Writer;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.util.ArrayList;


public class OWL2Parser {

	private static ArrayList<OWLOntology> loadedImportsList = new ArrayList<OWLOntology>();
	static private ArrayList<IRI> importsURI = new ArrayList<IRI>();

	public static void main(String[] args) {
		
		if (args.length < 1) {
			System.out.println("Usage: processor <URI> [FILENAME]");
			System.exit(1);
		}

		String filename = "";
		BufferedWriter out;

		// A simple example of how to load and save an ontology
		try {
			IRI iri = IRI.create(args[0]);
			OWLOntologyManager manager = OWLManager.createOWLOntologyManager();
			if (args.length == 2) {
				filename = args[1];
				out = new BufferedWriter(new FileWriter(filename));
			} else {
				out = new BufferedWriter(openForFile(null));
			}
			
			
			/* Load an ontology from a physical IRI */
			IRI physicalIRI = IRI.create(args[0]);
			//System.out.println("Loading : " + args[0]);
			
			// Now do the loading
			OWLOntology ontology = manager.loadOntologyFromOntologyDocument(physicalIRI);
			//System.out.println(ontology);
			
			// get all ontology which are imported from this ontology.
			getImportsList(ontology, manager);
			
			//System.out.println("LoadedImportsList: " + loadedImportsList);
			//System.out.println();

			if(loadedImportsList.size() == 0)
			{
				loadedImportsList.add(ontology);
				importsURI.add(manager.getOntologyDocumentIRI(ontology));
			}	
			

			for (OWLOntology onto : loadedImportsList) {
	                             
				//System.out.println("parsing OWL: " + onto.getOntologyID().getOntologyIRI() + " ...");
				ManchesterOWLSyntaxRenderer rendi = new ManchesterOWLSyntaxRenderer (onto.getOWLOntologyManager());
			
				rendi.render(onto,out);
	                      
	                        }

	  
	                //System.out.println("OWL parsing done!\n");
		} catch (IOException e) {
			System.err.println("Error: can not build file: " + filename);
			e.printStackTrace();
		} catch (Exception ex) {
			System.err.println("OWL parse error: " + ex.getMessage());
			ex.printStackTrace();
		}
	}

	private static void getImportsList(OWLOntology ontology,
			OWLOntologyManager om) {

		ArrayList<OWLOntology> unSavedImports = new ArrayList<OWLOntology>();
		
		try {
			for (OWLOntology imported : om.getImports(ontology)) {
				if (!importsURI.contains(imported.getOntologyID().getOntologyIRI())) {
					//System.out.println("IMPORTED: " + imported + "\n");
					unSavedImports.add(imported);
					loadedImportsList.add(imported);
					importsURI.add(imported.getOntologyID().getOntologyIRI());
				}
			}
			
			for (OWLOntology onto : unSavedImports) {
				getImportsList(onto, om);
			}

		} catch (Exception e) {
			System.err.println("Error!");
			e.printStackTrace();
		}
	}

	private static Writer openForFile(String fileName) 
		{ 		
			return new OutputStreamWriter(System.out);
		}
}


